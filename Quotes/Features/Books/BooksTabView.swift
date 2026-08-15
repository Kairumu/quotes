import SwiftUI

public struct BooksTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var collections: [BookCollection] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var appeared = false

    // Adaptive grid: 2 columns on regular width (iPad), list on compact (iPhone)
    private let gridColumns = [
        GridItem(.adaptive(minimum: 300, maximum: 500), spacing: QuotesSpacing.md)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                QuotesColor.surfacePrimary.ignoresSafeArea()
                contentBody
            }
            .navigationTitle("서재")
            .task { await loadCollections() }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if isLoading {
            VStack(spacing: QuotesSpacing.md) {
                ProgressView()
                    .tint(QuotesColor.accent)
                Text("불러오는 중…")
                    .font(.subheadline)
                    .foregroundStyle(QuotesColor.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = loadError {
            BrandedEmptyState(
                headline: "불러오기 실패",
                subtext: error.localizedDescription,
                systemImage: "exclamationmark.triangle",
                action: { Task { await loadCollections() } },
                actionLabel: "재시도"
            )
        } else if collections.isEmpty {
            BrandedEmptyState(
                headline: "서재가 비어 있어요",
                subtext: "컬렉션이 아직 없습니다",
                systemImage: "books.vertical"
            )
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: QuotesSpacing.md) {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { idx, collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                        } label: {
                            CollectionCardView(collection: collection)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                bookmarkCollection(collection)
                            } label: {
                                Label("컬렉션 북마크", systemImage: "books.vertical")
                            }
                        }
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.78)
                                .delay(Double(idx) * 0.06),
                            value: appeared
                        )
                    }
                }
                .padding(.horizontal, QuotesSpacing.md)
                .padding(.vertical, QuotesSpacing.md)
            }
            .onAppear { appeared = true }
        }
    }

    private func loadCollections() async {
        isLoading = true
        loadError = nil
        do {
            collections = try await env.contentRepository.collections()
        } catch {
            loadError = error
        }
        isLoading = false
    }

    private func bookmarkCollection(_ collection: BookCollection) {
        let bookmark = Bookmark(
            kind: .collection,
            name: collection.title,
            anchor: BookmarkAnchor(collectionId: collection.id)
        )
        env.bookmarks.add(bookmark)
    }
}

// MARK: - CollectionCardView

private struct CollectionCardView: View {
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
                    .foregroundStyle(QuotesColor.accent.opacity(0.85))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuotesColor.inkSecondary.opacity(0.4))
        }
        .padding(QuotesSpacing.md)
        .quotesCard()
    }
}
