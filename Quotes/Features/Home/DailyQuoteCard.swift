import SwiftUI

// MARK: - DailyQuoteCard
//
// 오늘의 문장: a large serif quote card over the source book's palette tint. The
// sentence is a deterministic daily pick from the shared `HomeModel` pool
// (day-of-year seed) — stable within a day, changing across days. Tapping deep
// links to that exact sentence in the reader (HomeRoute.reader).

struct DailyQuoteCard: View {
    let pooled: PooledSentence

    private var palette: BookPalette.Token { BookPalette.token(for: pooled.book) }

    var body: some View {
        NavigationLink(
            value: HomeRoute.reader(
                BookDestination(book: pooled.book, sentenceId: pooled.sentence.id)
            )
        ) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-daily-quote")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.md) {
            Text("오늘의 문장")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.heroInkSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Text("“\(pooled.text)”")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(palette.heroInk)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: QuotesSpacing.xs) {
                Text(pooled.book.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.heroInk)
                Text("·")
                    .foregroundStyle(palette.heroInkSecondary)
                Text(pooled.book.author)
                    .font(.footnote)
                    .foregroundStyle(palette.heroInkSecondary)
            }
            .lineLimit(1)
        }
        .padding(QuotesSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.backgroundGradient)
        .clipShape(RoundedRectangle(cornerRadius: QuotesShape.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: QuotesShape.cardCorner)
                .strokeBorder(QuotesColor.cardStroke.opacity(0.5), lineWidth: 1)
        )
    }
}
