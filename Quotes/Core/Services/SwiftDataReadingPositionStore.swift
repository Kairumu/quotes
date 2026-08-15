import Foundation
import SwiftData

/// SwiftData-backed `ReadingPositionStore` with upsert semantics (one record per book).
///
/// Must be created and used on the main actor. All fetch and save operations
/// are synchronous on `modelContainer.mainContext`.
///
/// - Note: A future `FirestoreReadingPositionStore` would sync reading positions
///   to `users/{uid}/positions/{bookId}` in Firestore, calling the same
///   `ReadingPositionStore` protocol so feature code requires no changes.
@MainActor
public final class SwiftDataReadingPositionStore: ReadingPositionStore, @unchecked Sendable {

    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        self.context = modelContainer.mainContext
    }

    // MARK: - ReadingPositionStore

    public func position(bookId: String) throws -> ReadingPosition? {
        let bid = bookId
        let descriptor = FetchDescriptor<ReadingPositionRecord>(
            predicate: #Predicate { $0.bookId == bid }
        )
        return try context.fetch(descriptor).first?.toDomain()
    }

    /// Upsert: updates the existing record for this book, or inserts a new one.
    public func save(_ position: ReadingPosition) throws {
        let bid = position.bookId
        let descriptor = FetchDescriptor<ReadingPositionRecord>(
            predicate: #Predicate { $0.bookId == bid }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: position)
        } else {
            context.insert(ReadingPositionRecord(position: position))
        }
        try context.save()
    }

    /// Fetch every saved position, sorted `updatedAt`-descending (most recent
    /// first). SwiftData performs the sort in the fetch descriptor.
    public func allPositions() throws -> [ReadingPosition] {
        let descriptor = FetchDescriptor<ReadingPositionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }
}
