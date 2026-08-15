import Foundation

/// Pure domain data for the content tree.
///
/// The content model is a tree of sentences with STABLE IDs. Every bookmark and
/// reading position anchors to sentence IDs — never page numbers.
///
/// ID convention (must match verbatim across the app and future Firestore data):
///   bookId       "b001"
///   chunkId      "b001-c001"
///   paragraphId  "b001-c001-p001"
///   sentenceId   "b001-c001-p001-s001"
///   collectionId "col-classics" (slug)

/// A curated grouping of books (e.g. "Aesop's Fables").
public struct BookCollection: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let bookIds: [String]
    /// Optional SF Symbol name used as a cover placeholder.
    public let coverSystemImage: String?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        bookIds: [String],
        coverSystemImage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.bookIds = bookIds
        self.coverSystemImage = coverSystemImage
    }
}

/// A single reading work. Its full text lives in the referenced chunks.
public struct Book: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let collectionId: String
    public let title: String
    public let author: String
    /// BCP-47-ish language code of the original text (e.g. "en").
    public let originalLanguage: String
    public let chunkIds: [String]
    /// Content revision; bump when the segmented text changes.
    public let version: Int

    public init(
        id: String,
        collectionId: String,
        title: String,
        author: String,
        originalLanguage: String,
        chunkIds: [String],
        version: Int
    ) {
        self.id = id
        self.collectionId = collectionId
        self.title = title
        self.author = author
        self.originalLanguage = originalLanguage
        self.chunkIds = chunkIds
        self.version = version
    }
}

/// One chapter/section of a book. Mirrors one Firestore chunk document.
public struct Chunk: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let bookId: String
    public let order: Int
    public let title: String?
    public let paragraphs: [Paragraph]

    public init(
        id: String,
        bookId: String,
        order: Int,
        title: String? = nil,
        paragraphs: [Paragraph]
    ) {
        self.id = id
        self.bookId = bookId
        self.order = order
        self.title = title
        self.paragraphs = paragraphs
    }
}

/// A paragraph within a chunk. Holds an ordered list of sentences.
public struct Paragraph: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let order: Int
    public let sentences: [Sentence]

    public init(id: String, order: Int, sentences: [Sentence]) {
        self.id = id
        self.order = order
        self.sentences = sentences
    }
}

/// The atomic anchor unit. Every position/bookmark points at sentence IDs.
public struct Sentence: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let order: Int
    public let text: String
    /// Language code → translated text (e.g. ["ko": "번역된 문장"]).
    public let translations: [String: String]

    public init(id: String, order: Int, text: String, translations: [String: String]) {
        self.id = id
        self.order = order
        self.text = text
        self.translations = translations
    }
}
