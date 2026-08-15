# iOS ↔ Firebase Integration Guide

This document is for the iOS workers implementing `TranslationService` and future `ContentRepository` Firestore backends.

---

## Required Swift Packages

Add via **Xcode → File → Add Package Dependencies**:

| Package | URL | Version |
|---------|-----|---------|
| Firebase iOS SDK | `https://github.com/firebase/firebase-ios-sdk` | `11.x` |

In your target, link these products:
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseFunctions`

---

## Authentication

All callables require a signed-in Firebase user. Configure Sign in with Apple:

```swift
import FirebaseAuth

// After receiving an ASAuthorization credential:
func signInWithApple(idToken: String, nonce: String) async throws {
    let credential = OAuthProvider.appleCredential(
        withIDToken: idToken,
        rawNonce: nonce,
        fullName: nil
    )
    try await Auth.auth().signIn(with: credential)
}
```

Check sign-in state before calling any callable:
```swift
guard Auth.auth().currentUser != nil else { throw AppError.unauthenticated }
```

---

## Calling `translateChunk`

### Request / Response shapes (mirror the backend exactly)

```swift
struct TranslateChunkRequest: Encodable {
    let bookId: String
    let chunkId: String
    let targetLang: String   // BCP-47, e.g. "ko", "ja", "fr"
}

struct TranslateChunkResponse: Decodable {
    let sentences: [String: String]   // sentenceId → translated text
    let cached: Bool
}
```

### Implementation

```swift
import FirebaseFunctions

final class FirebaseTranslationService: TranslationService {
    private let functions = Functions.functions()      // defaults to us-central1
    // If you deployed to a different region, use:
    // Functions.functions(region: "asia-northeast3")

    func availableLanguages(bookId: String) async -> [String] {
        // v1: sample content ships "ko"; extend when more langs are seeded
        return ["ko"]
    }

    func ensureTranslations(
        bookId: String,
        chunkId: String,
        language: String
    ) async throws {
        let req = TranslateChunkRequest(
            bookId: bookId,
            chunkId: chunkId,
            targetLang: language
        )
        // HTTPSCallable auto-encodes Encodable and decodes Decodable
        let _: TranslateChunkResponse = try await functions
            .httpsCallable("translateChunk")
            .call(req)
            .data(as: TranslateChunkResponse.self)
        // Result is cached server-side; subsequent calls are near-instant
    }
}
```

> **Note:** `FirebaseFunctions` encodes `Encodable` → JSON and decodes `Decodable` ← JSON automatically with the `call(_:).data(as:)` pattern. No manual serialization needed.

---

## Calling `pretranslateBook`

Pre-warms the translation cache for an entire book (useful on first launch or when switching language).

```swift
struct PretranslateBookRequest: Encodable {
    let bookId: String
    let targetLang: String
}

struct ChunkSummary: Decodable {
    let chunkId: String
    let cached: Bool
    let status: String   // "ok" | "error"
}

struct PretranslateBookResponse: Decodable {
    let bookId: String
    let targetLang: String
    let chunks: [ChunkSummary]
}

func pretranslateBook(bookId: String, language: String) async throws -> PretranslateBookResponse {
    let req = PretranslateBookRequest(bookId: bookId, targetLang: language)
    return try await Functions.functions()
        .httpsCallable("pretranslateBook")
        .call(req)
        .data(as: PretranslateBookResponse.self)
}
```

This function has a 540-second server timeout (large books). The call returns only after all chunks are processed. For UX, consider calling it in a background Task with progress feedback.

---

## Reading Translations from Firestore (offline / cache hit)

If you want to read the cached translation directly from Firestore (e.g., after `ensureTranslations` completes):

```swift
import FirebaseFirestore

struct TranslationDoc: Decodable {
    let sentences: [String: String]
    let model: String
    let version: Int
}

func loadTranslation(
    bookId: String,
    chunkId: String,
    lang: String
) async throws -> TranslationDoc? {
    let docId = "\(chunkId)_\(lang)"
    let snap = try await Firestore.firestore()
        .collection("translations")
        .document(bookId)
        .collection("chunks")
        .document(docId)
        .getDocument(as: TranslationDoc.self)
    return snap
}
```

Enable Firestore offline persistence (enabled by default in the iOS SDK) so translations survive app restarts without re-fetching.

---

## Reading Positions

```swift
struct ReadingPositionDoc: Codable {
    let chunkId: String
    let sentenceId: String
    let viewMode: String     // "sentence" | "paragraph"
    let updatedAt: Date
}

func savePosition(_ pos: ReadingPositionDoc, bookId: String, uid: String) async throws {
    try Firestore.firestore()
        .collection("users").document(uid)
        .collection("positions").document(bookId)
        .setData(from: pos, merge: false)
}

func loadPosition(bookId: String, uid: String) async throws -> ReadingPositionDoc? {
    try await Firestore.firestore()
        .collection("users").document(uid)
        .collection("positions").document(bookId)
        .getDocument(as: ReadingPositionDoc.self)
}
```

---

## Error Handling

Firebase callable errors map to `FunctionsErrorCode`:

| Server `HttpsError` code | `FunctionsErrorCode` |
|--------------------------|----------------------|
| `unauthenticated`        | `.unauthenticated`   |
| `invalid-argument`       | `.invalidArgument`   |
| `not-found`              | `.notFound`          |
| `internal`               | `.internal`          |
| `failed-precondition`    | `.failedPrecondition`|

```swift
do {
    try await translationService.ensureTranslations(...)
} catch let error as NSError {
    if let code = FunctionsErrorCode(rawValue: error.code) {
        switch code {
        case .unauthenticated: // prompt sign-in
        case .internal:        // show retry UI
        default: break
        }
    }
}
```

---

## Sentence ID Conventions (quick reference)

```
Collection : col-fables
Book       : b001
Chunk      : b001-c001
Paragraph  : b001-c001-p001
Sentence   : b001-c001-p001-s001
```

These IDs are stable and match across Firestore, the bundled JSON, and bookmark anchors.

---

## Future: FirestoreContentRepository

When upgrading from `LocalJSONContentRepository` to a Firestore backend, note:

### Chunk docs do NOT store `bookId`

Firestore chunk documents are stored at `books/{bookId}/chunks/{chunkId}`. The `bookId` field is **stripped** from the doc body (it's redundant with the path). However, the iOS `Chunk` Swift struct has a `bookId: String` field that must be populated.

**Pattern — inject bookId from query context:**

```swift
struct FirestoreChunkPayload: Decodable {
    let order: Int
    let title: String?
    let paragraphs: [Paragraph]
    // Note: NO bookId — it's not in the Firestore doc
}

func chunks(bookId: String) async throws -> [Chunk] {
    let snaps = try await Firestore.firestore()
        .collection("books").document(bookId)
        .collection("chunks")
        .getDocuments()

    return try snaps.documents.map { doc in
        let payload = try doc.data(as: FirestoreChunkPayload.self)
        // Inject bookId (from query parameter) and id (from doc.documentID)
        return Chunk(
            id: doc.documentID,
            bookId: bookId,          // ← inject from path, not from doc fields
            order: payload.order,
            title: payload.title,
            paragraphs: payload.paragraphs
        )
    }.sorted { $0.order < $1.order }
}
```

### Translations are in a separate subcollection

Do not look for a `translations` key on the chunk doc — it doesn't exist in Firestore. Translations live under `translations/{bookId}/chunks/{chunkId}_{lang}` and are fetched via `ensureTranslations` / the `translateChunk` callable.

### Book docs do not have `chunkCount` mismatch risk

`books/{bookId}` stores `chunkCount` (derived from `chunkIds.length` by the seed script). Treat `chunkIds` as the authoritative ordered list for fetching chunks.
