#!/usr/bin/env node
/**
 * seed.mjs — Seed Firestore from SampleContent JSON files.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json node scripts/seed.mjs --project <firebase-project-id>
 *
 * Reads from: ../Quotes/Resources/SampleContent/
 *   collections.json     — array of collection docs
 *   books.json           — array of book docs
 *   book-*-chunks.json   — one file per book, array of chunk docs
 *
 * Per-sentence "translations" maps are stripped from chunk docs and written
 * to translations/{bookId}/chunks/{chunkId}_{lang} with model "human-sample".
 */

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { readFileSync, readdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

// ── Resolve paths ─────────────────────────────────────────────────────────────

const __dirname = dirname(fileURLToPath(import.meta.url));
const SAMPLE_DIR = join(__dirname, "../Quotes/Resources/SampleContent");

// ── Parse CLI args ────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const projectIndex = args.indexOf("--project");
if (projectIndex === -1 || !args[projectIndex + 1]) {
  console.error("Usage: node scripts/seed.mjs --project <firebase-project-id>");
  process.exit(1);
}
const projectId = args[projectIndex + 1];

// ── Validate sample content directory ────────────────────────────────────────

if (!existsSync(SAMPLE_DIR)) {
  console.error(`\nSample content directory not found:\n  ${SAMPLE_DIR}\n`);
  console.error(
    "Please ensure the iOS worker has created:\n" +
    "  main/Quotes/Resources/SampleContent/collections.json\n" +
    "  main/Quotes/Resources/SampleContent/books.json\n" +
    "  main/Quotes/Resources/SampleContent/book-*-chunks.json\n"
  );
  process.exit(1);
}

function requireFile(name) {
  const p = join(SAMPLE_DIR, name);
  if (!existsSync(p)) {
    console.error(`Missing required file: ${p}`);
    process.exit(1);
  }
  return JSON.parse(readFileSync(p, "utf8"));
}

// ── Initialize Firebase Admin ─────────────────────────────────────────────────

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const db = getFirestore();

// ── Helpers ───────────────────────────────────────────────────────────────────

const BATCH_LIMIT = 490; // Firestore max is 500 ops per batch

class BatchWriter {
  constructor() {
    this.batch = db.batch();
    this.count = 0;
    this.total = 0;
  }

  set(ref, data) {
    this.batch.set(ref, data);
    this.count++;
    this.total++;
  }

  async flush() {
    if (this.count === 0) return;
    await this.batch.commit();
    console.log(`  committed ${this.count} writes (${this.total} total)`);
    this.batch = db.batch();
    this.count = 0;
  }

  async autoFlush() {
    if (this.count >= BATCH_LIMIT) await this.flush();
  }
}

// ── Extract and strip sentence-level translations ─────────────────────────────

/**
 * Recursively strips "translations" from each sentence in paragraphs.
 * Returns { cleanChunk, translationsByLang }
 *   translationsByLang: { [lang]: { [sentenceId]: translatedText } }
 */
function extractTranslations(chunkDoc) {
  const translationsByLang = {};
  const paragraphs = (chunkDoc.paragraphs || []).map((para) => {
    const sentences = (para.sentences || []).map((sentence) => {
      const { translations, ...cleanSentence } = sentence;
      if (translations && typeof translations === "object") {
        for (const [lang, text] of Object.entries(translations)) {
          if (!translationsByLang[lang]) translationsByLang[lang] = {};
          translationsByLang[lang][sentence.id] = text;
        }
      }
      return cleanSentence;
    });
    return { ...para, sentences };
  });

  const { translations: _unused, ...rest } = chunkDoc;
  void _unused;
  return { cleanChunk: { ...rest, paragraphs }, translationsByLang };
}

// ── Seed ──────────────────────────────────────────────────────────────────────

async function seed() {
  console.log(`\nSeeding project: ${projectId}`);
  console.log(`Source:          ${SAMPLE_DIR}\n`);

  const writer = new BatchWriter();

  // 1. Collections
  console.log("→ Seeding collections…");
  const collections = requireFile("collections.json");
  for (const col of collections) {
    const ref = db.collection("collections").doc(col.id || col.collectionId);
    const { id, collectionId: _cid, ...data } = col;
    void id; void _cid;
    writer.set(ref, data);
    await writer.autoFlush();
  }
  await writer.flush();

  // 2. Books
  console.log("→ Seeding books…");
  const books = requireFile("books.json");
  for (const book of books) {
    const bookId = book.id || book.bookId;
    const ref = db.collection("books").doc(bookId);
    const { id, bookId: _bid, ...data } = book;
    void id; void _bid;
    // Derive chunkCount from chunkIds if not explicitly provided
    const chunkCount = data.chunkCount ?? (data.chunkIds || []).length;
    writer.set(ref, { ...data, chunkCount });
    await writer.autoFlush();
  }
  await writer.flush();

  // 3. Chunks + translations
  console.log("→ Seeding chunks and translations…");

  const chunkFiles = readdirSync(SAMPLE_DIR).filter(
    (f) => f.startsWith("book-") && f.endsWith("-chunks.json")
  );

  if (chunkFiles.length === 0) {
    console.warn("  No book-*-chunks.json files found — skipping chunks.");
  }

  for (const fileName of chunkFiles) {
    // Derive bookId from filename: "book-b001-chunks.json" → "b001"
    const match = fileName.match(/^book-(.+)-chunks\.json$/);
    const bookId = match ? match[1] : fileName.replace("-chunks.json", "").replace("book-", "");

    console.log(`  Processing ${fileName} (bookId: ${bookId})…`);
    const chunks = JSON.parse(readFileSync(join(SAMPLE_DIR, fileName), "utf8"));

    for (const rawChunk of chunks) {
      const chunkId = rawChunk.id || rawChunk.chunkId;
      const { cleanChunk, translationsByLang } = extractTranslations(rawChunk);

      // Write chunk doc (strip id/bookId — both are encoded in the doc path)
      const { id, chunkId: _cid, bookId: _bid, ...chunkData } = cleanChunk;
      void id; void _cid; void _bid;
      const chunkRef = db
        .collection("books")
        .doc(bookId)
        .collection("chunks")
        .doc(chunkId);
      writer.set(chunkRef, chunkData);
      await writer.autoFlush();

      // Write translation cache docs
      for (const [lang, sentences] of Object.entries(translationsByLang)) {
        const translationDocId = `${chunkId}_${lang}`;
        const translationRef = db
          .collection("translations")
          .doc(bookId)
          .collection("chunks")
          .doc(translationDocId);
        writer.set(translationRef, {
          sentences,
          model: "human-sample",
          translatedAt: FieldValue.serverTimestamp(),
          version: 1,
        });
        await writer.autoFlush();
      }
    }
  }
  await writer.flush();

  console.log("\n✓ Seed complete.\n");
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
