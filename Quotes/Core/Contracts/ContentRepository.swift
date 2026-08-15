import Foundation

/// Read access to the content tree (collections → books → chunks).
///
/// v1 loads from bundled sample JSON; a later revision may back this with
/// Firestore. Callers must not assume a particular backing store.
public protocol ContentRepository: Sendable {
    /// All available collections.
    func collections() async throws -> [BookCollection]
    /// Books belonging to a collection, in listing order.
    func books(in collectionId: String) async throws -> [Book]
    /// A single book by ID.
    func book(id: String) async throws -> Book
    /// All chunks of a book, in reading order.
    func chunks(bookId: String) async throws -> [Chunk]
}
