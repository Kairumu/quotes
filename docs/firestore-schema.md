# Firestore Schema — Quotes Reading Platform

## Design Principles

### Stable Sentence IDs
Every piece of content has a deterministic, human-readable ID following the convention:

| Level       | Format                          | Example                     |
|-------------|---------------------------------|-----------------------------|
| Collection  | `col-{slug}`                    | `col-fables`                |
| Book        | `b{NNN}`                        | `b001`                      |
| Chunk       | `{bookId}-c{NNN}`               | `b001-c001`                 |
| Paragraph   | `{chunkId}-p{NNN}`              | `b001-c001-p001`            |
| Sentence    | `{paragraphId}-s{NNN}`          | `b001-c001-p001-s001`       |

IDs never change once assigned. Bookmarks, positions, and translation cache docs all key off these IDs.

### 1 MiB Chunk Budget
Firestore documents are limited to 1 MiB. Each `chunks` document represents one chapter/section. Keep chunks to a comfortable margin — a typical chapter of prose (~3,000 words / ~200 sentences) fits well under 200 KB. Split longer chapters into multiple chunk IDs if needed.

### Translation Cache Strategy
Translations are produced server-side by a Cloud Function that calls the LLM API (Anthropic) with **all sentences in one chunk in a single request** to maximise context quality. The result is cached in Firestore. Subsequent requests for the same `(bookId, chunkId, targetLang)` are served from cache without any LLM call. The iOS client **never** holds an LLM API key.

---

## Collections

### `collections/{collectionId}`

Curated groupings of books (e.g., "Aesop's Fables", "Classic Short Stories").

| Field      | Type       | Notes                          |
|------------|------------|--------------------------------|
| `title`    | `string`   | Display name                   |
| `subtitle` | `string`   | Optional tagline               |
| `bookIds`  | `string[]` | Ordered list of book IDs       |
| `order`    | `number`   | Sort order in discovery UI     |

---

### `books/{bookId}`

Top-level book metadata.

| Field              | Type       | Notes                                      |
|--------------------|------------|--------------------------------------------|
| `collectionId`     | `string`   | Parent collection                          |
| `title`            | `string`   |                                            |
| `author`           | `string`   |                                            |
| `originalLanguage` | `string`   | BCP-47 code, e.g. `"en"`, `"la"`          |
| `version`          | `number`   | Content version; bump to invalidate cache  |
| `chunkCount`       | `number`   | Total number of chunks                     |
| `chunkIds`         | `string[]` | Ordered list of chunk IDs                  |

---

### `books/{bookId}/chunks/{chunkId}`

One document per chapter/section. **Must stay well under 1 MiB.**

| Field        | Type     | Notes                                      |
|--------------|----------|--------------------------------------------|
| `order`      | `number` | Sort position within the book              |
| `title`      | `string` | Chapter/section title                      |
| `paragraphs` | `array`  | See Paragraph structure below              |

**Paragraph structure:**
```json
{
  "id": "b001-c001-p001",
  "order": 1,
  "sentences": [
    {
      "id": "b001-c001-p001-s001",
      "order": 1,
      "text": "The fox saw the grapes."
    }
  ]
}
```

---

### `translations/{bookId}/chunks/{chunkId}_{lang}`

LLM-generated (or human-sample) translation cache. Written only by Cloud Functions via the admin SDK; clients cannot write.

| Field          | Type        | Notes                                               |
|----------------|-------------|-----------------------------------------------------|
| `sentences`    | `map`       | `{ sentenceId: translatedText }` for every sentence |
| `model`        | `string`    | LLM model used, e.g. `"claude-sonnet-4-6"`, or `"human-sample"` |
| `translatedAt` | `timestamp` | Server-side timestamp                               |
| `version`      | `number`    | Matches book `version` at translation time          |

Document ID format: `{chunkId}_{lang}` — e.g. `b001-c001_ko`

**Read cost:** O(1) — one doc read per chunk per language per session.

---

### `users/{uid}/bookmarks/{bookmarkId}`

User-created highlights, captures, and saves.

| Field         | Type     | Notes                                                           |
|---------------|----------|-----------------------------------------------------------------|
| `kind`        | `string` | One of: `highlight`, `capture`, `page`, `book`, `collection`   |
| `name`        | `string` | User-supplied label                                             |
| `createdAt`   | `timestamp` |                                                              |
| `colorTag`    | `string` | Optional stable token name for highlight colour. One of: `amber` (default), `coral`, `sage`, `sky`, `lavender`. When `null` or absent, clients render as `amber`. Token names (vs. hex values) enable light/dark-adaptive rendering and survive palette retuning. |
| `emojiTag`    | `string` | Optional single emoji character from a fixed set (e.g. 📌⭐️❤️🔥🌿📖💡✏️). When set, clients render this emoji in place of the bookmark's kind icon in the UI. |
| `anchor`      | `map`    | See Anchor structure below                                      |

**Anchor structure:**
```json
{
  "collectionId": "col-fables",
  "bookId": "b001",
  "chunkId": "b001-c001",
  "sentenceIds": ["b001-c001-p001-s001", "b001-c001-p001-s002"],
  "startOffset": 0,
  "endOffset": 42
}
```

Security rules enforce `kind` to be one of the allowed values on create/update. Additive fields such as `colorTag` and `emojiTag` are not subject to field allowlisting and pass validation automatically.

---

### `users/{uid}/positions/{bookId}`

Last reading position per book, per user.

| Field       | Type        | Notes                          |
|-------------|-------------|--------------------------------|
| `chunkId`   | `string`    |                                |
| `sentenceId`| `string`    | First visible sentence         |
| `viewMode`  | `string`    | e.g. `"sentence"`, `"paragraph"` |
| `updatedAt` | `timestamp` |                                |

---

## Indexes

Two composite indexes are pre-deployed in `firestore.indexes.json` for the bookmark queries used by the Reader and My tab:

| Collection group | Fields                               | Use case                          |
|------------------|--------------------------------------|-----------------------------------|
| `bookmarks`      | `anchor.bookId` ASC, `createdAt` DESC | List a user's bookmarks for a specific book |
| `bookmarks`      | `kind` ASC, `createdAt` DESC          | Filter bookmarks by type (highlight / capture / page / book) |

All content reads (collections, books, chunks, translations) are direct document lookups by stable ID — no composite indexes required for those paths.

---

## Security Rules Summary

| Path                              | Read            | Write                     |
|-----------------------------------|-----------------|---------------------------|
| `collections/{id}`                | signed-in users | admin SDK only            |
| `books/{id}`                      | signed-in users | admin SDK only            |
| `books/{id}/chunks/{id}`          | signed-in users | admin SDK only            |
| `translations/{bookId}/chunks/*`  | signed-in users | admin SDK only (functions)|
| `users/{uid}/**`                  | owner only      | owner only                |
| `users/{uid}/bookmarks/{id}`      | owner only      | owner + kind validation   |
