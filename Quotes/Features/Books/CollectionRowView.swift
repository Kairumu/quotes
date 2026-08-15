import SwiftUI

struct CollectionRowView: View {
    let collection: BookCollection

    var body: some View {
        HStack(spacing: QuotesSpacing.md) {
            CollectionCoverTile(
                systemImage: collection.coverSystemImage,
                title: collection.title,
                size: 60
            )

            VStack(alignment: .leading, spacing: QuotesSpacing.xs) {
                Text(collection.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(QuotesColor.inkPrimary)
                    .lineLimit(1)

                if let subtitle = collection.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(QuotesColor.inkSecondary)
                        .lineLimit(1)
                }

                Text("책 \(collection.bookIds.count)권")
                    .font(.caption)
                    .foregroundStyle(QuotesColor.accent.opacity(0.8))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuotesColor.inkSecondary.opacity(0.5))
        }
        .padding(.vertical, QuotesSpacing.sm)
        .contentShape(Rectangle())
    }
}
