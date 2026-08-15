import Foundation
import SwiftData

/// SwiftData persistence record for a `ReadingPosition`. One per book.
@Model
public final class ReadingPositionRecord {
    /// Book ID is the natural unique key (one position per book).
    @Attribute(.unique) public var bookId: String
    public var chunkId: String
    public var sentenceId: String
    /// Raw value of `ReaderViewMode`.
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

    /// Map back to the domain `ReadingPosition`. Falls back to `.sentence` if
    /// the persisted view mode is unrecognized.
    func toDomain() -> ReadingPosition {
        ReadingPosition(
            bookId: bookId,
            chunkId: chunkId,
            sentenceId: sentenceId,
            viewMode: ReaderViewMode(rawValue: viewModeRaw) ?? .sentence,
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
