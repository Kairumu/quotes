import Foundation

/// The five kinds of user bookmark. Each carries a user-editable name.
public enum BookmarkKind: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    /// A highlighted sentence range with character offsets.
    case highlight
    /// A rendered image of a passage, anchored to a sentence range.
    case capture
    /// A saved reading position, anchored to the first visible sentence.
    case page
    /// A whole book.
    case book
    /// A whole collection.
    case collection

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .highlight: return "Highlight"
        case .capture: return "Capture"
        case .page: return "Page"
        case .book: return "Book"
        case .collection: return "Collection"
        }
    }

    /// A representative SF Symbol for the kind.
    public var systemImage: String {
        switch self {
        case .highlight: return "highlighter"
        case .capture: return "camera.viewfinder"
        case .page: return "bookmark"
        case .book: return "book"
        case .collection: return "books.vertical"
        }
    }
}

/// Locates a bookmark within the content tree by sentence IDs.
///
/// The set of populated fields depends on the bookmark kind:
///   - highlight: bookId, chunkId, sentenceIds (ordered), startOffset/endOffset
///   - capture:   bookId, chunkId, sentenceIds (ordered range)
///   - page:      bookId, chunkId, sentenceIds = [first visible sentence]
///   - book:      bookId
///   - collection: collectionId
///
/// `startOffset` / `endOffset` are character offsets within the first / last
/// sentence of `sentenceIds`, used only by the `highlight` kind.
public struct BookmarkAnchor: Codable, Sendable, Hashable {
    public let collectionId: String?
    public let bookId: String?
    public let chunkId: String?
    /// Ordered sentence IDs covered by the anchor (a contiguous range).
    public let sentenceIds: [String]
    /// Character offset into the first sentence (highlight kind only).
    public let startOffset: Int?
    /// Character offset into the last sentence (highlight kind only).
    public let endOffset: Int?

    public init(
        collectionId: String? = nil,
        bookId: String? = nil,
        chunkId: String? = nil,
        sentenceIds: [String] = [],
        startOffset: Int? = nil,
        endOffset: Int? = nil
    ) {
        self.collectionId = collectionId
        self.bookId = bookId
        self.chunkId = chunkId
        self.sentenceIds = sentenceIds
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

/// A user-created bookmark. Always anchored to sentence IDs (never page numbers).
public struct Bookmark: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let kind: BookmarkKind
    /// User-editable display name.
    public var name: String
    public let createdAt: Date
    public let anchor: BookmarkAnchor
    /// Optional color tag. Stores a stable palette token name
    /// (`amber|coral|sage|sky|lavender`), never a hex value.
    public var colorTag: String?
    /// Optional emoji tag (a single emoji character), shown in place of the
    /// kind icon in the bookmark row when present.
    public var emojiTag: String?

    public init(
        id: UUID = UUID(),
        kind: BookmarkKind,
        name: String,
        createdAt: Date = Date(),
        anchor: BookmarkAnchor,
        colorTag: String? = nil,
        emojiTag: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.createdAt = createdAt
        self.anchor = anchor
        self.colorTag = colorTag
        self.emojiTag = emojiTag
    }
}
