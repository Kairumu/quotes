import Foundation

/// In-memory, thread-safe placeholder implementations of the core contracts.
///
/// These exist so `AppEnvironment.placeholder()` compiles and runs (previews,
/// tests, early integration). The services worker delivers the real,
/// JSON/SwiftData-backed implementations that replace these.

/// A `ContentRepository` that returns empty results.
///
/// Loading from bundled sample JSON is the services worker's responsibility;
/// the placeholder intentionally ships no content.
public final class InMemoryContentRepository: ContentRepository, @unchecked Sendable {
    private let store: [BookCollection]
    private let booksById: [String: Book]
    private let chunksByBook: [String: [Chunk]]

    public init(
        collections: [BookCollection] = [],
        books: [Book] = [],
        chunks: [Chunk] = []
    ) {
        self.store = collections
        self.booksById = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        self.chunksByBook = Dictionary(grouping: chunks, by: { $0.bookId })
    }

    public func collections() async throws -> [BookCollection] {
        store
    }

    public func books(in collectionId: String) async throws -> [Book] {
        booksById.values.filter { $0.collectionId == collectionId }.sorted { $0.id < $1.id }
    }

    public func book(id: String) async throws -> Book {
        guard let book = booksById[id] else { throw ContentError.notFound(id) }
        return book
    }

    public func chunks(bookId: String) async throws -> [Chunk] {
        (chunksByBook[bookId] ?? []).sorted { $0.order < $1.order }
    }
}

/// Errors thrown by content repositories.
public enum ContentError: Error, Sendable, Equatable {
    case notFound(String)
}

/// A `TranslationService` that assumes translations are already embedded.
public final class NoopTranslationService: TranslationService, @unchecked Sendable {
    private let languages: [String]

    public init(languages: [String] = ["ko"]) {
        self.languages = languages
    }

    public func availableLanguages(bookId: String) async -> [String] {
        languages
    }

    public func ensureTranslations(bookId: String, chunkId: String, language: String) async throws {
        // Embedded translations — nothing to fetch.
    }
}

/// A thread-safe, array-backed `BookmarkStore`.
public final class InMemoryBookmarkStore: BookmarkStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Bookmark]

    public init(bookmarks: [Bookmark] = []) {
        self.storage = bookmarks
    }

    public func all() throws -> [Bookmark] {
        lock.lock(); defer { lock.unlock() }
        return storage.sorted { $0.createdAt > $1.createdAt }
    }

    public func bookmarks(kind: BookmarkKind) throws -> [Bookmark] {
        try all().filter { $0.kind == kind }
    }

    public func bookmarks(bookId: String) throws -> [Bookmark] {
        try all().filter { $0.anchor.bookId == bookId }
    }

    public func add(_ bookmark: Bookmark) throws {
        lock.lock(); defer { lock.unlock() }
        storage.append(bookmark)
    }

    public func rename(id: UUID, to name: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard let index = storage.firstIndex(where: { $0.id == id }) else {
            throw BookmarkStoreError.notFound(id)
        }
        storage[index].name = name
    }

    public func update(_ bookmark: Bookmark) throws {
        lock.lock(); defer { lock.unlock() }
        guard let index = storage.firstIndex(where: { $0.id == bookmark.id }) else {
            throw BookmarkStoreError.notFound(bookmark.id)
        }
        storage[index] = bookmark
    }

    public func delete(id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        storage.removeAll { $0.id == id }
    }
}

/// Errors thrown by bookmark stores.
public enum BookmarkStoreError: Error, Sendable, Equatable {
    case notFound(UUID)
}

/// A thread-safe, dictionary-backed `ReadingPositionStore`.
public final class InMemoryReadingPositionStore: ReadingPositionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: ReadingPosition]

    public init(positions: [ReadingPosition] = []) {
        self.storage = Dictionary(uniqueKeysWithValues: positions.map { ($0.bookId, $0) })
    }

    public func position(bookId: String) throws -> ReadingPosition? {
        lock.lock(); defer { lock.unlock() }
        return storage[bookId]
    }

    public func save(_ position: ReadingPosition) throws {
        lock.lock(); defer { lock.unlock() }
        storage[position.bookId] = position
    }
}
