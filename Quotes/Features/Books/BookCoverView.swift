import SwiftUI

// MARK: - BookCoverView
//
// A living, procedural 2:3 typographic book cover — Kakao's "content is the UI"
// translated to a reading app (the content is SENTENCES/TYPOGRAPHY). 100%
// procedural: a per-book `BookPalette` gradient background with a serif title
// "logotype", author line, and one representative sentence. ZERO image assets.
//
// PURE VIEW: it takes data only. The representative sentence is loaded by the
// CALLER (which owns the content repository) and injected — see
// `BookCoverContent.representativeSentence(from:)`. This keeps the cover cheap to
// render in grids/carousels and free of async work. P2/P3/P5 build against the
// stable init below verbatim.
//
// UI-TEST HOOK: the root carries `.accessibilityIdentifier("book-cover-<bookId>")`
// so a UI test can tap a known cover deterministically (e.g. `book-cover-b001`).

struct BookCoverView: View {

    /// Render size. `grid` fills the available width (2-up gallery tiles);
    /// `compact` is a smaller fixed cover for list rows / horizontal carousels.
    enum Size {
        case grid
        case compact
    }

    let book: Book
    /// One representative sentence (v1: first sentence of the first chunk),
    /// loaded and passed by the caller. `nil` → title-only until loaded.
    let representativeSentence: String?
    var size: Size = .grid

    init(book: Book, representativeSentence: String? = nil, size: Size = .grid) {
        self.book = book
        self.representativeSentence = representativeSentence
        self.size = size
    }

    private var palette: BookPalette.Token { BookPalette.token(for: book) }

    private var titleFont: Font {
        switch size {
        case .grid:    return .system(size: 26, weight: .bold, design: .serif)
        case .compact: return .system(size: 18, weight: .bold, design: .serif)
        }
    }

    private var authorFont: Font {
        switch size {
        case .grid:    return .system(size: 13, weight: .medium, design: .serif)
        case .compact: return .system(size: 11, weight: .medium, design: .serif)
        }
    }

    private var sentenceFont: Font {
        switch size {
        case .grid:    return .system(size: 13, weight: .regular, design: .serif)
        case .compact: return .system(size: 11, weight: .regular, design: .serif)
        }
    }

    private var padding: CGFloat {
        switch size {
        case .grid:    return QuotesSpacing.md
        case .compact: return QuotesSpacing.sm + 2
        }
    }

    private var titleLineLimit: Int {
        switch size {
        case .grid:    return 4
        case .compact: return 3
        }
    }

    private var sentenceLineLimit: Int {
        switch size {
        case .grid:    return 3
        case .compact: return 2
        }
    }

    var body: some View {
        if size == .grid {
            coverStack
                .coverBreathing(seed: BookPalette.fnv1a(book.id))
        } else {
            // .compact (carousels, list rows) stays completely static for
            // scroll performance — no TimelineView ticking in long lists.
            coverStack
        }
    }

    /// The cover visual content, shared between the animated (.grid) and static
    /// (.compact) render paths. Motion is applied externally in `body`.
    @ViewBuilder
    private var coverStack: some View {
        ZStack {
            palette.backgroundGradient

            VStack(alignment: .leading, spacing: QuotesSpacing.xs) {
                Text(book.title)
                    .font(titleFont)
                    .foregroundStyle(palette.heroInk)
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.author)
                    .font(authorFont)
                    .foregroundStyle(palette.heroInkSecondary)
                    .lineLimit(1)

                Spacer(minLength: QuotesSpacing.sm)

                if let sentence = representativeSentence, !sentence.isEmpty {
                    Text(sentence)
                        .font(sentenceFont)
                        .italic()
                        .foregroundStyle(palette.heroInkSecondary)
                        .lineLimit(sentenceLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(padding)
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: QuotesShape.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: QuotesShape.cardCorner)
                .strokeBorder(QuotesColor.cardStroke.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("book-cover-\(book.id)")
    }
}

// MARK: - BookCoverContent (caller-side helper)

/// Shared, caller-side derivation of a cover's representative sentence.
///
/// The cover view is pure; callers (서재 gallery, collection detail, and later the
/// Home feed / Book Detail) load a book's chunks and resolve the representative
/// sentence once, then inject it. v1 rule: first sentence of the first chunk,
/// using the reader's canonical ordering (chunks by `order`, paragraphs by
/// `order`, sentences by `order`).
/// A book paired with its preloaded representative sentence, ready to feed a
/// `BookCoverView`. Shared by the 서재 gallery and collection detail (and reusable
/// by later Home/Detail surfaces) so the caller-side load pattern is uniform.
struct BookCoverItem: Identifiable {
    let book: Book
    let representativeSentence: String?
    var id: String { book.id }
}

enum BookCoverContent {
    static func representativeSentence(from chunks: [Chunk]) -> String? {
        chunks
            .sorted { $0.order < $1.order }
            .first?
            .paragraphs
            .sorted { $0.order < $1.order }
            .first?
            .sentences
            .sorted { $0.order < $1.order }
            .first?
            .text
    }
}
