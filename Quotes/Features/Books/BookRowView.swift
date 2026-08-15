import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: QuotesSpacing.md) {
            // Mini cover tile
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(QuotesColor.accentTint)
                    .frame(width: 36, height: 48)
                Image(systemName: "text.book.closed")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(QuotesColor.accent)
            }

            VStack(alignment: .leading, spacing: QuotesSpacing.xs) {
                Text(book.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(QuotesColor.inkPrimary)
                    .lineLimit(2)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(QuotesColor.inkSecondary)
                    .lineLimit(1)

                LanguageBadge(code: book.originalLanguage)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, QuotesSpacing.sm)
        .contentShape(Rectangle())
    }
}
