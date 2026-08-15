import Foundation

/// Persists and retrieves the user's reading position per book.
public protocol ReadingPositionStore: Sendable {
    /// The saved position for a book, if any.
    func position(bookId: String) throws -> ReadingPosition?
    /// Insert or update the position for its book.
    func save(_ position: ReadingPosition) throws
    /// All saved positions across every book (unordered).
    ///
    /// Purely additive read used by the 홈 feed to resolve the cross-book
    /// "most recent" 이어 읽기 target without N per-book queries. Callers sort by
    /// `updatedAt` (most recent = `allPositions().max(by: updatedAt)`).
    func allPositions() throws -> [ReadingPosition]
}
