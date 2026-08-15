import SwiftUI

// MARK: - ContinueReadingHero
//
// The 이어 읽기 lead block: a full-bleed palette hero for the most-recently-read
// book. Pure view — all data (title, sentence preview, progress) is derived by
// `HomeModel` (C4: index/total computed independently of the reader). STATIC by
// design; cover/hero motion is Phase 5's responsibility, not this task's.
//
// The whole card is a value-based deep link into the reader at the saved
// sentence (HomeRoute.reader), following the root-registered routing discipline.

struct ContinueReadingHero: View {
    let target: ContinueReadingTarget

    private var palette: BookPalette.Token { BookPalette.token(for: target.book) }

    private var progressPercent: Int { Int((target.progress * 100).rounded()) }

    var body: some View {
        NavigationLink(
            value: HomeRoute.reader(
                BookDestination(book: target.book, sentenceId: target.sentenceId)
            )
        ) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-continue-hero")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.md) {
            Text("이어 읽기")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.heroInkSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(target.book.title)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(palette.heroInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !target.sentenceText.isEmpty {
                Text("“\(target.sentenceText)”")
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(palette.heroInkSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if target.totalCount > 0 {
                progressBlock
            }

            cta
        }
        .padding(QuotesSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.backgroundGradient)
        .clipShape(RoundedRectangle(cornerRadius: QuotesShape.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: QuotesShape.cardCorner)
                .strokeBorder(QuotesColor.cardStroke.opacity(0.5), lineWidth: 1)
        )
        .coverBreathing(seed: BookPalette.fnv1a(target.book.id))
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.heroInk.opacity(0.15))
                    Capsule()
                        .fill(palette.heroInk.opacity(0.55))
                        .frame(width: max(4, geo.size.width * target.progress))
                }
            }
            .frame(height: 5)

            Text("\(progressPercent)% · \(target.sentenceNumber) / \(target.totalCount)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.heroInkSecondary)
        }
    }

    private var cta: some View {
        HStack(spacing: QuotesSpacing.xs) {
            Image(systemName: "book.fill")
                .font(.caption)
            Text("이어 읽기")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(palette.heroInk)
        .padding(.horizontal, QuotesSpacing.md)
        .padding(.vertical, QuotesSpacing.sm)
        .background(palette.heroInk.opacity(0.12), in: Capsule())
    }
}
