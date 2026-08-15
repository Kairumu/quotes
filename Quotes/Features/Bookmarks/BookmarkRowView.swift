import SwiftUI

/// Reusable row: kind-colored icon tile, name (headline), context + relative date (caption).
///
/// Display rules (C2/C3):
/// - Leading tile tint: highlight rows → HighlightPalette.color(forTag:) (nil → amber);
///   all other kinds → bookmark.kind.kindColor.
/// - Tile content: if emojiTag != nil → emoji text in place of kind icon; nil → kind systemImage.
public struct BookmarkRowView: View {
    let bookmark: Bookmark
    let contextTitle: String?

    public init(bookmark: Bookmark, contextTitle: String?) {
        self.bookmark = bookmark
        self.contextTitle = contextTitle
    }

    /// Tile tint color.  Highlight rows use the palette color (nil → amber default).
    private var tileColor: Color {
        bookmark.kind == .highlight
            ? HighlightPalette.color(forTag: bookmark.colorTag)
            : bookmark.kind.kindColor
    }

    public var body: some View {
        HStack(spacing: QuotesSpacing.md) {
            // Leading icon tile — emoji renders in place of kind icon when set.
            ZStack {
                RoundedRectangle(cornerRadius: QuotesShape.badgeCorner + 2)
                    .fill(tileColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                if let emoji = bookmark.emojiTag {
                    Text(emoji)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: bookmark.kind.systemImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(tileColor)
                }
            }

            VStack(alignment: .leading, spacing: QuotesSpacing.xs) {
                Text(bookmark.name)
                    .font(.system(.subheadline, design: .default).weight(.medium))
                    .foregroundStyle(QuotesColor.inkPrimary)
                    .lineLimit(1)

                HStack(spacing: QuotesSpacing.xs) {
                    Text(bookmark.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(QuotesColor.inkSecondary)

                    if let title = contextTitle {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(QuotesColor.inkSecondary.opacity(0.5))
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(QuotesColor.inkSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, QuotesSpacing.xs + 2)
        .contentShape(Rectangle())
    }
}
