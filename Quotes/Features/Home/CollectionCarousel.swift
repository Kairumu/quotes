import SwiftUI

// MARK: - CollectionCarousel
//
// Horizontal carousel of collections, each with a hardcoded editorial one-liner
// (Korean) keyed by collectionId for v1. Reads collections from the shared
// `HomeModel` (A3) — no separate load. Tapping routes to the collection detail
// via the value-based HomeRoute at the Home stack root.

struct CollectionCarousel: View {
    let collections: [BookCollection]

    var body: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.sm) {
            SectionHeader(title: "컬렉션")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: QuotesSpacing.md) {
                    ForEach(collections) { collection in
                        NavigationLink(value: HomeRoute.collection(collection)) {
                            CollectionCarouselCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home-collection-\(collection.id)")
                    }
                }
                .padding(.horizontal, QuotesSpacing.md)
            }
        }
    }
}

// MARK: - Card

private struct CollectionCarouselCard: View {
    let collection: BookCollection

    /// Editorial one-liner copy map (hardcoded Korean per plan, keyed by id).
    /// Falls back to the collection's own subtitle, then a generic line.
    private var editorialLine: String {
        HomeEditorialCopy.collectionLine(for: collection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.sm) {
            Image(systemName: collection.coverSystemImage ?? "books.vertical")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(QuotesColor.accent)
                .frame(width: 40, height: 40)
                .background(QuotesColor.accentTint, in: RoundedRectangle(cornerRadius: QuotesShape.iconCorner))

            Text(collection.title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(QuotesColor.inkPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(editorialLine)
                .font(.footnote)
                .foregroundStyle(QuotesColor.inkSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(QuotesSpacing.md)
        .frame(width: 220, height: 170, alignment: .topLeading)
        .quotesCard()
    }
}

// MARK: - HomeEditorialCopy

/// Hardcoded Korean editorial copy for the 홈 feed (v1). Keyed by collectionId.
enum HomeEditorialCopy {
    private static let collectionLines: [String: String] = [
        "col-fables": "짧지만 오래 남는 이야기, 우화 속 지혜를 만나요.",
        "col-meditations": "스스로에게 건네는 고요한 성찰의 문장들."
    ]

    static func collectionLine(for collection: BookCollection) -> String {
        if let line = collectionLines[collection.id] { return line }
        if let subtitle = collection.subtitle, !subtitle.isEmpty { return subtitle }
        return "천천히 음미하는 문장 모음."
    }
}

// MARK: - SectionHeader (shared across 홈 blocks)

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.title3, design: .serif).weight(.semibold))
            .foregroundStyle(QuotesColor.inkPrimary)
            .padding(.horizontal, QuotesSpacing.md)
    }
}
