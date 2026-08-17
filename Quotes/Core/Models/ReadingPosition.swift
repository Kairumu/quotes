import Foundation

/// The user's last reading position within a book.
///
/// Anchored to a sentence ID so it survives re-pagination and layout changes.
///
/// - Note: `viewMode` is **officially vestigial**. It is still written on every
///   position save (for record/schema compat) but is **never read back** — the
///   reader mode's single source of truth is the global `reader.viewMode`
///   UserDefaults key (`AppEnvironment.viewMode`). Only `sentenceId` is restored.
public struct ReadingPosition: Codable, Sendable, Hashable, Identifiable {
    public let bookId: String
    public let chunkId: String
    public let sentenceId: String
    /// Vestigial: persisted for record compat, never read back. See type note.
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
