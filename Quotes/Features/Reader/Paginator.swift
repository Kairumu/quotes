import SwiftUI
import UIKit

/// A unit that gets packed onto a page. Chunk titles and sentences are both
/// blocks; a sentence block's height includes its translation when shown.
enum PageBlock: Identifiable, Hashable {
    case title(chunkId: String, text: String)
    case sentence(Sentence, chunkId: String)

    var id: String {
        switch self {
        case .title(let chunkId, _): return "title:\(chunkId)"
        case .sentence(let sentence, _): return "sentence:\(sentence.id)"
        }
    }

    /// The chunk this block belongs to.
    var chunkId: String {
        switch self {
        case .title(let chunkId, _): return chunkId
        case .sentence(_, let chunkId): return chunkId
        }
    }

    /// The sentence id if this block is a sentence, else nil.
    var sentenceId: String? {
        if case .sentence(let sentence, _) = self { return sentence.id }
        return nil
    }
}

/// Identifies a unique pagination layout. Pages are DERIVED from sentence
/// anchors and cached per key; any change recomputes automatically.
///
/// Fields cover every input that affects packed geometry: content revision,
/// page content size, dynamic type, and translation display settings. Font
/// settings are fully captured by `dynamicTypeSize` today (the base faces are
/// fixed in `ReaderStyle`); the field is kept explicit so future user font
/// settings extend the key cleanly.
struct LayoutKey: Hashable {
    let bookVersion: Int
    let width: CGFloat
    let height: CGFloat
    let dynamicTypeSize: DynamicTypeSize
    let showTranslation: Bool
    let translationLanguage: String

    /// Quantise the size so sub-point jitter doesn't thrash the cache.
    init(
        bookVersion: Int,
        size: CGSize,
        dynamicTypeSize: DynamicTypeSize,
        showTranslation: Bool,
        translationLanguage: String
    ) {
        self.bookVersion = bookVersion
        self.width = size.width.rounded()
        self.height = size.height.rounded()
        self.dynamicTypeSize = dynamicTypeSize
        self.showTranslation = showTranslation
        self.translationLanguage = translationLanguage
    }

    var contentSize: CGSize { CGSize(width: width, height: height) }
}

/// The result of paginating a book for one layout key.
struct PaginatedBook {
    let pages: [[PageBlock]]
    /// Sentence id → page index containing it (for position landing / bookmarks).
    let pageIndexBySentence: [String: Int]

    /// The first sentence id appearing on `page`, if any.
    func firstSentenceId(onPage page: Int) -> String? {
        guard pages.indices.contains(page) else { return nil }
        return pages[page].compactMap(\.sentenceId).first
    }
}

/// Measures sentence/title block heights offscreen with TextKit and greedily
/// packs them into pages that fit a content rect. Measurement mirrors
/// `SentenceRowView` geometry (fonts, line spacing, paddings) closely enough
/// that on-screen pages do not overflow.
enum Paginator {
    /// A small per-block safety margin (points) absorbing minor differences
    /// between TextKit measurement and SwiftUI's rendered line breaking.
    private static let blockSafetyMargin: CGFloat = 2

    static func paginate(
        chunks: [Chunk],
        orderedSentences: (String) -> [Sentence],
        key: LayoutKey
    ) -> PaginatedBook {
        let blocks = buildBlocks(chunks: chunks, orderedSentences: orderedSentences)
        guard key.width > 1, key.height > 1, !blocks.isEmpty else {
            return PaginatedBook(pages: blocks.isEmpty ? [] : [blocks], pageIndexBySentence: [:])
        }

        let fonts = Fonts(dynamicTypeSize: key.dynamicTypeSize)
        let contentHeight = key.height
        let originalWidth = max(1, key.width - 2 * ReaderStyle.rowHorizontalPadding)
        let translationWidth = max(1, originalWidth - ReaderStyle.translationLeadingInset)
        let titleWidth = originalWidth

        var pages: [[PageBlock]] = []
        var current: [PageBlock] = []
        var currentHeight: CGFloat = 0

        func height(of block: PageBlock) -> CGFloat {
            switch block {
            case .title(_, let text):
                let h = measure(text, font: fonts.title, lineSpacing: 0, width: titleWidth)
                return ReaderStyle.titleTopPadding + h + ReaderStyle.titleBottomPadding + blockSafetyMargin
            case .sentence(let sentence, _):
                var h = measure(
                    sentence.text,
                    font: fonts.original,
                    lineSpacing: ReaderStyle.lineSpacing,
                    width: originalWidth
                )
                if key.showTranslation, let translation = sentence.translations[key.translationLanguage] {
                    let th = measure(
                        translation,
                        font: fonts.translation,
                        lineSpacing: ReaderStyle.lineSpacing,
                        width: translationWidth
                    )
                    h += ReaderStyle.rowInternalSpacing + th
                }
                return ReaderStyle.rowVerticalPadding * 2 + h + blockSafetyMargin
            }
        }

        for block in blocks {
            let blockHeight = height(of: block)
            let needed = current.isEmpty ? blockHeight : currentHeight + ReaderStyle.rowSpacing + blockHeight
            if !current.isEmpty && needed > contentHeight {
                pages.append(current)
                current = [block]
                currentHeight = blockHeight
            } else {
                current.append(block)
                currentHeight = needed
            }
        }
        if !current.isEmpty { pages.append(current) }
        if pages.isEmpty { pages = [[]] }

        var indexBySentence: [String: Int] = [:]
        for (pageIndex, page) in pages.enumerated() {
            for block in page {
                if let sentenceId = block.sentenceId {
                    indexBySentence[sentenceId] = pageIndex
                }
            }
        }

        return PaginatedBook(pages: pages, pageIndexBySentence: indexBySentence)
    }

    /// Flattens chunks into ordered blocks: a title (when present) followed by
    /// each sentence in reading order.
    private static func buildBlocks(
        chunks: [Chunk],
        orderedSentences: (String) -> [Sentence]
    ) -> [PageBlock] {
        var blocks: [PageBlock] = []
        for chunk in chunks.sorted(by: { $0.order < $1.order }) {
            if let title = chunk.title {
                blocks.append(.title(chunkId: chunk.id, text: title))
            }
            for sentence in orderedSentences(chunk.id) {
                blocks.append(.sentence(sentence, chunkId: chunk.id))
            }
        }
        return blocks
    }

    // MARK: TextKit measurement

    private static func measure(
        _ text: String,
        font: UIFont,
        lineSpacing: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        let bounds = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(bounds.height)
    }

    /// UIFonts that mirror the SwiftUI faces used in `SentenceRowView`, scaled
    /// for the active dynamic type size.
    private struct Fonts {
        let original: UIFont
        let translation: UIFont
        let title: UIFont

        init(dynamicTypeSize: DynamicTypeSize) {
            let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.contentSizeCategory)
            // .system(.body, design: .serif)
            let bodyBase = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
            let serifDescriptor = bodyBase.fontDescriptor.withDesign(.serif) ?? bodyBase.fontDescriptor
            original = UIFont(descriptor: serifDescriptor, size: bodyBase.pointSize)
            // .callout
            translation = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: traits)
            // .title3.bold()
            let titleBase = UIFont.preferredFont(forTextStyle: .title3, compatibleWith: traits)
            let boldDescriptor = titleBase.fontDescriptor.withSymbolicTraits(.traitBold) ?? titleBase.fontDescriptor
            title = UIFont(descriptor: boldDescriptor, size: titleBase.pointSize)
        }
    }
}

extension DynamicTypeSize {
    /// Maps a SwiftUI dynamic type size to the equivalent UIKit content size
    /// category so TextKit measurement scales identically to SwiftUI rendering.
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}
