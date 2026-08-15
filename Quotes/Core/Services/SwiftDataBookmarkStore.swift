import Foundation
import SwiftData

/// SwiftData-backed `BookmarkStore` using the main model context.
///
/// Must be created and used on the main actor. All fetch and save operations
/// are synchronous on `modelContainer.mainContext`.
///
/// Results are sorted by `createdAt` descending (newest first).
///
/// - Note: A future `FirestoreBookmarkStore` would sync bookmarks to
///   `users/{uid}/bookmarks` in Firestore, calling the same `BookmarkStore`
///   protocol so feature code requires no changes.
@MainActor
public final class SwiftDataBookmarkStore: BookmarkStore, @unchecked Sendable {

    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        self.context = modelContainer.mainContext
    }

    // MARK: - BookmarkStore

    public func all() throws -> [Bookmark] {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).compactMap { $0.toDomain() }
    }

    public func bookmarks(kind: BookmarkKind) throws -> [Bookmark] {
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.kindRaw == kindRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).compactMap { $0.toDomain() }
    }

    public func bookmarks(bookId: String) throws -> [Bookmark] {
        let bid = bookId
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.bookId == bid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).compactMap { $0.toDomain() }
    }

    public func add(_ bookmark: Bookmark) throws {
        let record = BookmarkRecord(bookmark: bookmark)
        context.insert(record)
        try context.save()
    }

    public func rename(id: UUID, to name: String) throws {
        let targetId = id
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == targetId }
        )
        guard let record = try context.fetch(descriptor).first else {
            throw BookmarkStoreError.notFound(id)
        }
        record.name = name
        try context.save()
    }

    public func update(_ bookmark: Bookmark) throws {
        let targetId = bookmark.id
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == targetId }
        )
        guard let record = try context.fetch(descriptor).first else {
            throw BookmarkStoreError.notFound(bookmark.id)
        }
        record.update(from: bookmark)
        try context.save()
    }

    public func delete(id: UUID) throws {
        let targetId = id
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.id == targetId }
        )
        guard let record = try context.fetch(descriptor).first else {
            throw BookmarkStoreError.notFound(id)
        }
        context.delete(record)
        try context.save()
    }
}
