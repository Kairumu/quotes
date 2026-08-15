import Foundation
import SwiftData

/// SwiftData persistence record for a `Bookmark`.
///
/// Anchor fields are stored flat (strings/ints) with the ordered `sentenceIds`
/// array JSON-encoded, so the schema stays simple and query-friendly.
@Model
public final class BookmarkRecord {
    /// Stable identity, matching `Bookmark.id`.
    @Attribute(.unique) public var id: UUID
    /// Raw value of `BookmarkKind`.
    public var kindRaw: String
    public var name: String
    public var createdAt: Date
    public var colorTag: String?
    /// Optional emoji tag (single emoji character). Additive optional attribute
    /// → SwiftData lightweight automatic migration; existing rows decode as nil.
    public var emojiTag: String?

    // Flattened `BookmarkAnchor`.
    public var collectionId: String?
    public var bookId: String?
    public var chunkId: String?
    /// JSON-encoded `[String]` of ordered sentence IDs.
    public var sentenceIdsJSON: String
    public var startOffset: Int?
    public var endOffset: Int?

    public init(
        id: UUID,
        kindRaw: String,
        name: String,
        createdAt: Date,
        colorTag: String?,
        emojiTag: String?,
        collectionId: String?,
        bookId: String?,
        chunkId: String?,
        sentenceIdsJSON: String,
        startOffset: Int?,
        endOffset: Int?
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.name = name
        self.createdAt = createdAt
        self.colorTag = colorTag
        self.emojiTag = emojiTag
        self.collectionId = collectionId
        self.bookId = bookId
        self.chunkId = chunkId
        self.sentenceIdsJSON = sentenceIdsJSON
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

public extension BookmarkRecord {
    /// Build a record from a domain `Bookmark`.
    convenience init(bookmark: Bookmark) {
        self.init(
            id: bookmark.id,
            kindRaw: bookmark.kind.rawValue,
            name: bookmark.name,
            createdAt: bookmark.createdAt,
            colorTag: bookmark.colorTag,
            emojiTag: bookmark.emojiTag,
            collectionId: bookmark.anchor.collectionId,
            bookId: bookmark.anchor.bookId,
            chunkId: bookmark.anchor.chunkId,
            sentenceIdsJSON: BookmarkRecord.encode(bookmark.anchor.sentenceIds),
            startOffset: bookmark.anchor.startOffset,
            endOffset: bookmark.anchor.endOffset
        )
    }

    /// Map back to the domain `Bookmark`. Returns nil if the persisted kind is
    /// unrecognized (schema drift safety).
    func toDomain() -> Bookmark? {
        guard let kind = BookmarkKind(rawValue: kindRaw) else { return nil }
        let anchor = BookmarkAnchor(
            collectionId: collectionId,
            bookId: bookId,
            chunkId: chunkId,
            sentenceIds: BookmarkRecord.decode(sentenceIdsJSON),
            startOffset: startOffset,
            endOffset: endOffset
        )
        return Bookmark(
            id: id,
            kind: kind,
            name: name,
            createdAt: createdAt,
            anchor: anchor,
            colorTag: colorTag,
            emojiTag: emojiTag
        )
    }

    /// Overwrite this record's fields from a domain `Bookmark` (same identity).
    func update(from bookmark: Bookmark) {
        kindRaw = bookmark.kind.rawValue
        name = bookmark.name
        createdAt = bookmark.createdAt
        colorTag = bookmark.colorTag
        emojiTag = bookmark.emojiTag
        collectionId = bookmark.anchor.collectionId
        bookId = bookmark.anchor.bookId
        chunkId = bookmark.anchor.chunkId
        sentenceIdsJSON = BookmarkRecord.encode(bookmark.anchor.sentenceIds)
        startOffset = bookmark.anchor.startOffset
        endOffset = bookmark.anchor.endOffset
    }

    static func encode(_ sentenceIds: [String]) -> String {
        guard let data = try? JSONEncoder().encode(sentenceIds),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func decode(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return ids
    }
}
