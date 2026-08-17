import Foundation
import SwiftData

/// SwiftData persistence record for a `ReadingPosition`. One per book.
@Model
public final class ReadingPositionRecord {
    /// Book ID is the natural unique key (one position per book).
    @Attribute(.unique) public var bookId: String
    public var chunkId: String
    public var sentenceId: String
    /// Raw value of `ReaderViewMode`. **Vestigial**: still written for record
    /// compat, never read back to drive the reader mode (the global
    /// `reader.viewMode` UserDefaults key is the single source of truth). Old
    /// raws (`"sentence"`/`"paragraph"`/`"page"`) decode unchanged.
    public var viewModeRaw: String
    public var updatedAt: Date

    public init(
        bookId: String,
        chunkId: String,
        sentenceId: String,
        viewModeRaw: String,
        updatedAt: Date
    ) {
        self.bookId = bookId
        self.chunkId = chunkId
        self.sentenceId = sentenceId
        self.viewModeRaw = viewModeRaw
        self.updatedAt = updatedAt
    }
}

public extension ReadingPositionRecord {
    convenience init(position: ReadingPosition) {
        self.init(
            bookId: position.bookId,
            chunkId: position.chunkId,
            sentenceId: position.sentenceId,
            viewModeRaw: position.viewMode.rawValue,
            updatedAt: position.updatedAt
        )
    }

    /// Map back to the domain `ReadingPosition`. The `viewMode` is vestigial
    /// (never consumed); the unknown-raw fallback of `.continuous` is defensive
    /// only. `sentenceId` is the value that actually gets restored.
    func toDomain() -> ReadingPosition {
        ReadingPosition(
            bookId: bookId,
            chunkId: chunkId,
            sentenceId: sentenceId,
            viewMode: ReaderViewMode(rawValue: viewModeRaw) ?? .continuous,
            updatedAt: updatedAt
        )
    }

    func update(from position: ReadingPosition) {
        chunkId = position.chunkId
        sentenceId = position.sentenceId
        viewModeRaw = position.viewMode.rawValue
        updatedAt = position.updatedAt
    }
}
