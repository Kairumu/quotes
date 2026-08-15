#!/usr/bin/env node
/**
 * validate-schema.mjs — Validates SampleContent JSON files against the
 * Quotes Firestore schema and ID-convention rules.
 *
 * Usage:
 *   node scripts/validate-schema.mjs
 *
 * Exits 0 if all checks pass, 1 if any error is found.
 */

import { readFileSync, readdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SAMPLE_DIR = join(__dirname, "../Quotes/Resources/SampleContent");
const CHUNK_SIZE_WARN_BYTES = 512 * 1024;  // warn at 512 KiB
const CHUNK_SIZE_ERROR_BYTES = 900 * 1024; // error at 900 KiB (under 1 MiB limit)

// ── Utilities ─────────────────────────────────────────────────────────────────

let errors = 0;
let warnings = 0;

function err(msg) {
  console.error(`  ✗ ERROR: ${msg}`);
  errors++;
}

function warn(msg) {
  console.warn(`  ⚠ WARN:  ${msg}`);
  warnings++;
}

function ok(msg) {
  console.log(`  ✓ ${msg}`);
}

function requireFile(name) {
  const p = join(SAMPLE_DIR, name);
  if (!existsSync(p)) {
    err(`Missing required file: ${name}`);
    return null;
  }
  try {
    return JSON.parse(readFileSync(p, "utf8"));
  } catch (e) {
    err(`Invalid JSON in ${name}: ${e.message}`);
    return null;
  }
}

// ID format regexes (mirrors ID convention in Content.swift)
const ID_PATTERNS = {
  collection: /^col-[a-z0-9][a-z0-9-]*$/,
  book:       /^b\d{3,}$/,
  chunk:      /^b\d{3,}-c\d{3,}$/,
  paragraph:  /^b\d{3,}-c\d{3,}-p\d{3,}$/,
  sentence:   /^b\d{3,}-c\d{3,}-p\d{3,}-s\d{3,}$/,
};

function checkId(id, kind, context) {
  if (!id) { err(`${context}: missing ${kind} id`); return false; }
  if (!ID_PATTERNS[kind].test(id)) {
    err(`${context}: ${kind} id "${id}" does not match convention (expected ${ID_PATTERNS[kind]})`);
    return false;
  }
  return true;
}

// ── Validate ──────────────────────────────────────────────────────────────────

async function validate() {
  console.log(`\nValidating sample content at:\n  ${SAMPLE_DIR}\n`);

  if (!existsSync(SAMPLE_DIR)) {
    err(`Sample content directory does not exist: ${SAMPLE_DIR}`);
    printSummary();
    return;
  }

  // ── 1. Collections ──────────────────────────────────────────────────────────
  console.log("── collections.json ──────────────────────────────────────");
  const collections = requireFile("collections.json");
  if (!collections) { printSummary(); return; }
  if (!Array.isArray(collections)) { err("collections.json must be an array"); printSummary(); return; }

  const collectionIds = new Set();
  const collectionBookIds = new Set();

  for (const col of collections) {
    checkId(col.id, "collection", `collection "${col.id}"`);
    if (collectionIds.has(col.id)) err(`Duplicate collection id: ${col.id}`);
    collectionIds.add(col.id);

    if (!col.title) err(`collection "${col.id}": missing title`);
    if (!Array.isArray(col.bookIds) || col.bookIds.length === 0)
      err(`collection "${col.id}": bookIds must be a non-empty array`);

    for (const bid of (col.bookIds || [])) collectionBookIds.add(bid);
  }
  ok(`${collections.length} collection(s) validated`);

  // ── 2. Books ────────────────────────────────────────────────────────────────
  console.log("\n── books.json ────────────────────────────────────────────");
  const books = requireFile("books.json");
  if (!books) { printSummary(); return; }
  if (!Array.isArray(books)) { err("books.json must be an array"); printSummary(); return; }

  const bookIds = new Set();
  const bookChunkIds = new Map(); // bookId → Set of expected chunkIds

  for (const book of books) {
    checkId(book.id, "book", `book "${book.id}"`);
    if (bookIds.has(book.id)) err(`Duplicate book id: ${book.id}`);
    bookIds.add(book.id);

    if (!book.title)    err(`book "${book.id}": missing title`);
    if (!book.author)   err(`book "${book.id}": missing author`);
    if (!book.originalLanguage) err(`book "${book.id}": missing originalLanguage`);
    if (!book.collectionId)     err(`book "${book.id}": missing collectionId`);
    if (!collectionIds.has(book.collectionId))
      err(`book "${book.id}": collectionId "${book.collectionId}" not found in collections.json`);

    if (!Array.isArray(book.chunkIds) || book.chunkIds.length === 0)
      err(`book "${book.id}": chunkIds must be a non-empty array`);

    const chunkSet = new Set(book.chunkIds || []);
    bookChunkIds.set(book.id, chunkSet);

    for (const cid of (book.chunkIds || [])) {
      if (!cid.startsWith(book.id + "-")) {
        err(`book "${book.id}": chunkId "${cid}" should start with "${book.id}-"`);
      }
    }
  }

  // Check every bookId referenced in collections exists
  for (const bid of collectionBookIds) {
    if (!bookIds.has(bid))
      err(`Collection references book "${bid}" which is not in books.json`);
  }
  ok(`${books.length} book(s) validated`);

  // ── 3. Chunks ───────────────────────────────────────────────────────────────
  console.log("\n── book-*-chunks.json files ──────────────────────────────");

  const chunkFiles = readdirSync(SAMPLE_DIR).filter(
    (f) => f.startsWith("book-") && f.endsWith("-chunks.json")
  );

  if (chunkFiles.length === 0) {
    warn("No book-*-chunks.json files found");
  }

  const globalSentenceIds = new Set();
  let totalSentences = 0;

  for (const fileName of chunkFiles.sort()) {
    const match = fileName.match(/^book-(.+)-chunks\.json$/);
    const fileBookId = match ? match[1] : null;

    let chunks;
    try {
      chunks = JSON.parse(readFileSync(join(SAMPLE_DIR, fileName), "utf8"));
    } catch (e) {
      err(`Invalid JSON in ${fileName}: ${e.message}`);
      continue;
    }

    if (!Array.isArray(chunks)) { err(`${fileName}: must be an array`); continue; }

    console.log(`\n  ${fileName} (${chunks.length} chunk(s)):`);
    const seenChunkIds = new Set();

    for (const chunk of chunks) {
      const chunkId = chunk.id;
      checkId(chunkId, "chunk", `${fileName} chunk "${chunkId}"`);
      if (seenChunkIds.has(chunkId)) err(`${fileName}: duplicate chunkId "${chunkId}"`);
      seenChunkIds.add(chunkId);

      // bookId in chunk data should match filename-derived bookId
      if (fileBookId && chunk.bookId && chunk.bookId !== fileBookId) {
        err(`${fileName}: chunk "${chunkId}" has bookId "${chunk.bookId}" but filename implies "${fileBookId}"`);
      }
      const effectiveBookId = chunk.bookId || fileBookId;

      // Chunk should be listed in its book's chunkIds
      if (effectiveBookId && bookChunkIds.has(effectiveBookId)) {
        if (!bookChunkIds.get(effectiveBookId).has(chunkId)) {
          err(`${fileName}: chunk "${chunkId}" is not listed in book "${effectiveBookId}" chunkIds`);
        }
      }

      // Check chunkId prefix matches bookId
      if (effectiveBookId && !chunkId.startsWith(effectiveBookId + "-")) {
        err(`chunk "${chunkId}" should start with "${effectiveBookId}-"`);
      }

      if (typeof chunk.order !== "number") err(`chunk "${chunkId}": order must be a number`);

      // Size check (JSON bytes as proxy for Firestore doc size)
      const chunkBytes = Buffer.byteLength(JSON.stringify(chunk), "utf8");
      if (chunkBytes > CHUNK_SIZE_ERROR_BYTES) {
        err(`chunk "${chunkId}": ${(chunkBytes / 1024).toFixed(0)} KiB — exceeds 900 KiB safety limit (Firestore max: 1 MiB)`);
      } else if (chunkBytes > CHUNK_SIZE_WARN_BYTES) {
        warn(`chunk "${chunkId}": ${(chunkBytes / 1024).toFixed(0)} KiB — approaching 1 MiB limit`);
      }

      // Paragraphs
      if (!Array.isArray(chunk.paragraphs) || chunk.paragraphs.length === 0) {
        err(`chunk "${chunkId}": paragraphs must be a non-empty array`);
        continue;
      }

      for (const para of chunk.paragraphs) {
        checkId(para.id, "paragraph", `chunk "${chunkId}" paragraph "${para.id}"`);
        if (!para.id.startsWith(chunkId + "-")) {
          err(`paragraph "${para.id}" should start with "${chunkId}-"`);
        }
        if (typeof para.order !== "number") err(`paragraph "${para.id}": order must be a number`);

        if (!Array.isArray(para.sentences) || para.sentences.length === 0) {
          err(`paragraph "${para.id}": sentences must be a non-empty array`);
          continue;
        }

        for (const sentence of para.sentences) {
          checkId(sentence.id, "sentence", `paragraph "${para.id}" sentence "${sentence.id}"`);
          if (!sentence.id.startsWith(para.id + "-")) {
            err(`sentence "${sentence.id}" should start with "${para.id}-"`);
          }
          if (typeof sentence.order !== "number") err(`sentence "${sentence.id}": order must be a number`);
          if (!sentence.text || sentence.text.trim() === "") err(`sentence "${sentence.id}": text is empty`);

          // Global uniqueness
          if (globalSentenceIds.has(sentence.id)) {
            err(`DUPLICATE sentence id globally: "${sentence.id}"`);
          }
          globalSentenceIds.add(sentence.id);
          totalSentences++;

          // Validate embedded translations (optional)
          if (sentence.translations && typeof sentence.translations === "object") {
            for (const [lang, text] of Object.entries(sentence.translations)) {
              if (!/^[a-z]{2,3}(-[A-Z]{2,4})?$/.test(lang)) {
                warn(`sentence "${sentence.id}": translation key "${lang}" is not a valid BCP-47 tag`);
              }
              if (!text || text.trim() === "") {
                err(`sentence "${sentence.id}": translation["${lang}"] is empty`);
              }
            }
          }
        }
      }
    }

    // Verify all chunkIds declared in the book exist in this file
    if (fileBookId && bookChunkIds.has(fileBookId)) {
      for (const expectedId of bookChunkIds.get(fileBookId)) {
        if (!seenChunkIds.has(expectedId)) {
          err(`book "${fileBookId}" declares chunkId "${expectedId}" but it was not found in ${fileName}`);
        }
      }
    }

    ok(`${fileName}: ${seenChunkIds.size} chunk(s), all IDs valid`);
  }

  console.log(`\n── Summary ───────────────────────────────────────────────`);
  console.log(`  Collections : ${collections.length}`);
  console.log(`  Books       : ${books.length}`);
  console.log(`  Chunk files : ${chunkFiles.length}`);
  console.log(`  Sentences   : ${totalSentences} (${globalSentenceIds.size} unique IDs)`);

  printSummary();
}

function printSummary() {
  console.log();
  if (errors === 0 && warnings === 0) {
    console.log("✅ All checks passed.\n");
  } else {
    if (warnings > 0) console.warn(`⚠  ${warnings} warning(s)`);
    if (errors > 0)   console.error(`❌ ${errors} error(s) — schema is invalid.\n`);
    else              console.log("✅ No errors (warnings only).\n");
  }
  if (errors > 0) process.exit(1);
}

validate().catch((e) => {
  console.error("Unexpected error:", e);
  process.exit(1);
});
