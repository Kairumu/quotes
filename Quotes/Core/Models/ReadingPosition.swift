import Foundation

/// The user's last reading position within a book.
///
/// Anchored to a sentence ID so it survives re-pagination and layout changes.
public struct ReadingPosition: Codable, Sendable, Hashable, Identifiable {
    public let bookId: String
    public let chunkId: String
    public let sentenceId: String
    public let viewMode: ReaderViewMode
    public let updatedAt: Date

    /// One position per book — the book ID is a natural identity.
    public var id: String { bookId }

    public init(
        bookId: String,
        chunkId: String,
        sentenceId: String,
        viewMode: ReaderViewMode,
        updatedAt: Date = Date()
    ) {
        self.bookId = bookId
        self.chunkId = chunkId
        self.sentenceId = sentenceId
        self.viewMode = viewMode
        self.updatedAt = updatedAt
    }
}
