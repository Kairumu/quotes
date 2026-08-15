import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {
  getChunk,
  getBook,
  getTranslation,
  setTranslation,
} from "./firestore";
import { translateSentences, SentenceInput } from "./llm";

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

// ── Validation helpers ────────────────────────────────────────────────────────

/** Basic BCP-47 check: "ko", "en", "zh-TW", "pt-BR", etc. */
const LANG_RE = /^[a-z]{2,3}(-[A-Z]{2,4})?$/;

function validateLang(lang: string, fieldName: string): void {
  if (!LANG_RE.test(lang)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} "${lang}" is not a valid BCP-47 language code (e.g. "ko", "en", "zh-TW")`
    );
  }
}

// ── Request / Response types ──────────────────────────────────────────────────

interface TranslateChunkRequest {
  bookId: string;
  chunkId: string;
  targetLang: string;
}

interface TranslateChunkResponse {
  sentences: Record<string, string>;
  cached: boolean;
}

interface PretranslateBookRequest {
  bookId: string;
  targetLang: string;
}

interface ChunkSummary {
  chunkId: string;
  cached: boolean;
  status: "ok" | "error";
}

interface PretranslateBookResponse {
  bookId: string;
  targetLang: string;
  chunks: ChunkSummary[];
}

// ── Core read-through translate logic ─────────────────────────────────────────

async function translateChunkCore(
  bookId: string,
  chunkId: string,
  targetLang: string,
  apiKey: string,
  sourceLang = "auto"
): Promise<TranslateChunkResponse> {
  // 1. Check translation cache
  const cached = await getTranslation(bookId, chunkId, targetLang);
  if (cached) {
    return { sentences: cached.sentences, cached: true };
  }

  // 2. Load chunk document
  const chunk = await getChunk(bookId, chunkId);

  // 3. Collect all sentences (preserving stable IDs)
  const allSentences: SentenceInput[] = [];
  for (const para of chunk.paragraphs) {
    for (const sentence of para.sentences) {
      allSentences.push({ id: sentence.id, text: sentence.text });
    }
  }

  if (allSentences.length === 0) {
    throw new HttpsError("failed-precondition", `Chunk ${chunkId} has no sentences`);
  }

  const expectedIds = new Set(allSentences.map((s) => s.id));

  // 4. Translate — retry once if sentence IDs are missing from response
  let translations: Record<string, string> | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    const result = await translateSentences(allSentences, sourceLang, targetLang, apiKey);
    const missingIds = [...expectedIds].filter((id) => !(id in result));

    if (missingIds.length === 0) {
      translations = result;
      break;
    }

    logger.warn(`translateChunkCore: attempt ${attempt + 1} missing IDs`, {
      bookId,
      chunkId,
      targetLang,
      missingCount: missingIds.length,
      missingIds,
    });

    if (attempt === 1) {
      throw new HttpsError(
        "internal",
        `Translation incomplete: ${missingIds.length} sentence(s) missing after retry`
      );
    }
  }

  if (!translations) {
    throw new HttpsError("internal", "Translation failed unexpectedly");
  }

  // 5. Write to cache (admin SDK — bypasses Firestore rules)
  await setTranslation(bookId, chunkId, targetLang, {
    sentences: translations,
    model: "claude-sonnet-4-6",
    version: 1,
  });

  return { sentences: translations, cached: false };
}

// ── Cloud Functions ───────────────────────────────────────────────────────────

/**
 * Callable: translateChunk
 * Translates a single chunk, returning cached result when available.
 *
 * Request:  { bookId: string, chunkId: string, targetLang: string }
 * Response: { sentences: Record<sentenceId, translatedText>, cached: boolean }
 */
export const translateChunk = onCall(
  { secrets: [anthropicApiKey] },
  async (request): Promise<TranslateChunkResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { bookId, chunkId, targetLang } =
      request.data as TranslateChunkRequest;

    if (!bookId || !chunkId || !targetLang) {
      throw new HttpsError(
        "invalid-argument",
        "bookId, chunkId, and targetLang are required"
      );
    }
    validateLang(targetLang, "targetLang");

    try {
      return await translateChunkCore(
        bookId,
        chunkId,
        targetLang,
        anthropicApiKey.value()
      );
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("translateChunk: unhandled error", { bookId, chunkId, targetLang, err });
      throw new HttpsError("internal", "Translation failed");
    }
  }
);

/**
 * Callable: pretranslateBook
 * Pre-warms the translation cache for every chunk in a book sequentially.
 *
 * Request:  { bookId: string, targetLang: string }
 * Response: { bookId, targetLang, chunks: [{ chunkId, cached, status }] }
 */
export const pretranslateBook = onCall(
  { secrets: [anthropicApiKey], timeoutSeconds: 540 },
  async (request): Promise<PretranslateBookResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { bookId, targetLang } = request.data as PretranslateBookRequest;

    if (!bookId || !targetLang) {
      throw new HttpsError("invalid-argument", "bookId and targetLang are required");
    }
    validateLang(targetLang, "targetLang");

    let book;
    try {
      book = await getBook(bookId);
    } catch (err) {
      logger.error("pretranslateBook: book not found", { bookId, err });
      throw new HttpsError("not-found", `Book ${bookId} not found`);
    }

    const summary: ChunkSummary[] = [];

    for (const chunkId of book.chunkIds) {
      try {
        const result = await translateChunkCore(
          bookId,
          chunkId,
          targetLang,
          anthropicApiKey.value(),
          book.originalLanguage
        );
        summary.push({ chunkId, cached: result.cached, status: "ok" });
      } catch (err) {
        logger.error("pretranslateBook: chunk failed", { bookId, chunkId, targetLang, err });
        summary.push({ chunkId, cached: false, status: "error" });
      }
    }

    return { bookId, targetLang, chunks: summary };
  }
);
