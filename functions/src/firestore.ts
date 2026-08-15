import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

// ── Domain types ──────────────────────────────────────────────────────────────

export interface Sentence {
  id: string;
  order: number;
  text: string;
}

export interface Paragraph {
  id: string;
  order: number;
  sentences: Sentence[];
}

export interface ChunkDoc {
  order: number;
  title: string;
  paragraphs: Paragraph[];
}

export interface BookDoc {
  collectionId: string;
  title: string;
  author: string;
  originalLanguage: string;
  version: number;
  chunkCount: number;
  chunkIds: string[];
}

export interface TranslationDoc {
  sentences: Record<string, string>;
  model: string;
  translatedAt: Timestamp;
  version: number;
}

interface TranslationWriteData {
  sentences: Record<string, string>;
  model: string;
  version: number;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function db() {
  return getFirestore();
}

export async function getChunk(bookId: string, chunkId: string): Promise<ChunkDoc> {
  const snap = await db()
    .collection("books")
    .doc(bookId)
    .collection("chunks")
    .doc(chunkId)
    .get();
  if (!snap.exists) {
    throw new Error(`Chunk not found: books/${bookId}/chunks/${chunkId}`);
  }
  return snap.data() as ChunkDoc;
}

export async function getBook(bookId: string): Promise<BookDoc> {
  const snap = await db().collection("books").doc(bookId).get();
  if (!snap.exists) {
    throw new Error(`Book not found: books/${bookId}`);
  }
  return snap.data() as BookDoc;
}

export async function getTranslation(
  bookId: string,
  chunkId: string,
  lang: string
): Promise<TranslationDoc | null> {
  const docId = `${chunkId}_${lang}`;
  const snap = await db()
    .collection("translations")
    .doc(bookId)
    .collection("chunks")
    .doc(docId)
    .get();
  if (!snap.exists) return null;
  return snap.data() as TranslationDoc;
}

export async function setTranslation(
  bookId: string,
  chunkId: string,
  lang: string,
  data: TranslationWriteData
): Promise<void> {
  const docId = `${chunkId}_${lang}`;
  await db()
    .collection("translations")
    .doc(bookId)
    .collection("chunks")
    .doc(docId)
    .set({
      ...data,
      translatedAt: FieldValue.serverTimestamp(),
    });
}
