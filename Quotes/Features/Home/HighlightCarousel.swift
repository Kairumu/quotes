import SwiftUI

// MARK: - HighlightCarousel
//
// 내 하이라이트: a horizontal carousel of the user's highlight bookmarks rendered
// as quote chips. Reads highlights live from `env.bookmarks` (passed in by the
// parent so it re-renders on every mutation) and resolves each chip's text +
// owning book from the shared `HomeModel` (A3). Tapping deep links to the exact
// highlighted sentence (HomeRoute.reader). Empty → the block is absent (the
// parent omits it), no crash.

struct HighlightCarousel: View {
    let highlights: [Bookmark]
    let model: HomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.sm) {
            SectionHeader(title: "내 하이라이트")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: QuotesSpacing.md) {
                    ForEach(highlights) { bookmark in
                        chip(for: bookmark)
                    }
                }
                .padding(.horizontal, QuotesSpacing.md)
            }
        }
    }

    @ViewBuilder
    private func chip(for bookmark: Bookmark) -> some View {
        let text = model.highlightText(for: bookmark)
        if let bookId = bookmark.anchor.bookId,
           let book = model.book(id: bookId),
           let sentenceId = bookmark.anchor.sentenceIds.first {
            NavigationLink(
                value: HomeRoute.reader(BookDestination(book: book, sentenceId: sentenceId))
            ) {
                HighlightChip(text: text, book: book)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-highlight-\(bookmark.id.uuidString)")
        }
    }
}

// MARK: - Chip

private struct HighlightChip: View {
    let text: String
    let book: Book

    private var palette: BookPalette.Token { BookPalette.token(for: book) }

    var body: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.sm) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundStyle(palette.heroInkSecondary)

            Text(text)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(palette.heroInk)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(book.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.heroInkSecondary)
                .lineLimit(1)
        }
        .padding(QuotesSpacing.md)
        .frame(width: 240, height: 160, alignment: .topLeading)
        .background(palette.backgroundGradient)
        .clipShape(RoundedRectangle(cornerRadius: QuotesShape.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: QuotesShape.cardCorner)
                .strokeBorder(QuotesColor.cardStroke.opacity(0.5), lineWidth: 1)
        )
    }
}
