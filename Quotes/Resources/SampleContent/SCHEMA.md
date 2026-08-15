# Sample Content Schema

Pre-segmented, bundled reading content. This mirrors the future Firestore
document layout (one `Chunk` JSON object ≈ one Firestore chunk document).

## ID convention (must match exactly across the app)

| Level      | Format                     | Example                   |
|------------|----------------------------|---------------------------|
| collection | `col-<slug>`               | `col-fables`              |
| book       | `b<NNN>`                   | `b001`                    |
| chunk      | `b<NNN>-c<NNN>`            | `b001-c001`               |
| paragraph  | `b<NNN>-c<NNN>-p<NNN>`     | `b001-c001-p001`          |
| sentence   | `b<NNN>-c<NNN>-p<NNN>-s<NNN>` | `b001-c001-p001-s001`  |

All bookmarks and reading positions anchor to **sentence IDs**, never page
numbers.

## Files

- `collections.json` — array of `BookCollection`
- `books.json` — array of `Book`
- `book-<bookId>-chunks.json` — array of `Chunk` for one book

## Types (decoded by `Quotes/Core/Models`)

### BookCollection
```json
{
  "id": "col-fables",
  "title": "Aesop's Fables",
  "subtitle": "Timeless short tales",   // optional
  "bookIds": ["b001", "b002"],
  "coverSystemImage": "tortoise"        // optional SF Symbol
}
```

### Book
```json
{
  "id": "b001",
  "collectionId": "col-fables",
  "title": "The Tortoise and the Hare",
  "author": "Aesop",
  "originalLanguage": "en",
  "chunkIds": ["b001-c001", "b001-c002"],
  "version": 1
}
```

### Chunk → Paragraph → Sentence
```json
{
  "id": "b001-c001",
  "bookId": "b001",
  "order": 0,
  "title": "The Challenge",            // optional
  "paragraphs": [
    {
      "id": "b001-c001-p001",
      "order": 0,
      "sentences": [
        {
          "id": "b001-c001-p001-s001",
          "order": 0,
          "text": "A hare was making fun of the tortoise ...",
          "translations": { "ko": "어느 날 토끼가 거북이를 놀리고 있었다 ..." }
        }
      ]
    }
  ]
}
```

`translations` maps a language code → translated text. v1 ships Korean (`ko`)
for every sentence. Additional languages may be added by the translation
service without changing this schema.
