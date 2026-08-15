import Foundation

/// Loads the three bundled JSON content files (`collections.json`, `books.json`,
/// and `book-<bookId>-chunks.json`) and serves them through `ContentRepository`.
///
/// Data is decoded once per process lifetime and cached in-memory. Thread safety
/// is provided by the internal `ContentCache` actor.
///
/// - Note: A future `FirestoreContentRepository` would replace this type, reading
///   from Firestore collections `collections`, `books`, and `books/{id}/chunks`
///   using the Firestore iOS SDK.
public final class LocalJSONContentRepository: ContentRepository, @unchecked Sendable {

    private let bundle: Bundle
    private let cache = ContentCache()

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    // MARK: - ContentRepository

    public func collections() async throws -> [BookCollection] {
        if let cached = await cache.collections { return cached }
        let decoded = try load([BookCollection].self, resource: "collections")
        await cache.setCollections(decoded)
        return decoded
    }

    public func books(in collectionId: String) async throws -> [Book] {
        return try await allBooks().filter { $0.collectionId == collectionId }
    }

    public func book(id: String) async throws -> Book {
        guard let book = try await allBooks().first(where: { $0.id == id }) else {
            throw ContentError.notFound(id)
        }
        return book
    }

    public func chunks(bookId: String) async throws -> [Chunk] {
        if let cached = await cache.chunks(for: bookId) { return cached }
        let decoded = try load([Chunk].self, resource: "book-\(bookId)-chunks")
        let sorted = decoded.sorted { $0.order < $1.order }
        await cache.setChunks(sorted, for: bookId)
        return sorted
    }

    // MARK: - Private helpers

    private func allBooks() async throws -> [Book] {
        if let cached = await cache.books { return cached }
        let decoded = try load([Book].self, resource: "books")
        await cache.setBooks(decoded)
        return decoded
    }

    /// Locate a JSON file in the bundle and decode it.
    private func load<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw ContentError.notFound(resource)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Internal cache actor

private actor ContentCache {
    var collections: [BookCollection]?
    var books: [Book]?
    private var chunksByBookId: [String: [Chunk]] = [:]

    func setCollections(_ value: [BookCollection]) { collections = value }
    func setBooks(_ value: [Book]) { books = value }
    func chunks(for bookId: String) -> [Chunk]? { chunksByBookId[bookId] }
    func setChunks(_ value: [Chunk], for bookId: String) { chunksByBookId[bookId] = value }
}
