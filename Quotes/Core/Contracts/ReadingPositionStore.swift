import Foundation

/// Persists and retrieves the user's reading position per book.
public protocol ReadingPositionStore: Sendable {
    /// The saved position for a book, if any.
    func position(bookId: String) throws -> ReadingPosition?
    /// Insert or update the position for its book.
    func save(_ position: ReadingPosition) throws
}
