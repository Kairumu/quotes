import SwiftUI

public struct BooksTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var collections: [BookCollection] = []
    /// All books across all collections, paired with a preloaded representative
    /// sentence for their living cover. The caller (this view) owns the content
    /// repository, so it resolves the sentence once and injects it into the pure
    /// `BookCoverView` (keeps covers cheap + async-free).
    @State private var items: [BookCoverItem] = []
    /// Selected collection filter; `nil` = 전체 (all books).
    @State private var selectedCollectionId: String?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var appeared = false

    // 2-up on iPhone; more columns on iPad via the adaptive minimum.
    private let gridColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 240), spacing: QuotesSpacing.md)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                QuotesColor.surfacePrimary.ignoresSafeArea()
                contentBody
            }
            .navigationTitle("서재")
            // Value-based routing (Phase 3). ALL Books-stack destinations are
            // registered ONCE here at the stack ROOT via the single `BooksRoute`
            // enum — never on a pushed child, and never double-registered under a
            // bare `BookDestination`/`Book`/`BookCollection`. This follows the
            // `MyRoute` pattern and prevents the double-push / overlap bug class.
            .navigationDestination(for: BooksRoute.self) { route in
                switch route {
                case .collection(let collection):
                    CollectionDetailView(collection: collection)
                case .bookDetail(let book):
                    BookDetailView(book: book)
                case .reader(let destination):
                    ReaderScreen(book: destination.book, initialSentenceId: destination.sentenceId)
                }
            }
            .task { await loadData() }
        }
    }

    /// Books filtered by the selected collection chip.
    private var visibleItems: [BookCoverItem] {
        guard let id = selectedCollectionId else { return items }
        return items.filter { $0.book.collectionId == id }
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
                action: { Task { await loadData() } },
                actionLabel: "재시도"
            )
        } else if items.isEmpty {
            BrandedEmptyState(
                headline: "서재가 비어 있어요",
                subtext: "컬렉션이 아직 없습니다",
                systemImage: "books.vertical"
            )
        } else {
            VStack(spacing: 0) {
                collectionChips
                // When a specific collection is filtered, surface a value-based
                // entry into its CollectionDetailView (the flat gallery replaced
                // the old collection cards in Phase 1, leaving detail unreachable).
                if let collection = selectedCollection {
                    collectionHeader(collection)
                }
                gallery
            }
        }
    }

    /// The `BookCollection` currently selected by the filter chip, if any.
    private var selectedCollection: BookCollection? {
        guard let id = selectedCollectionId else { return nil }
        return collections.first { $0.id == id }
    }

    /// A tappable header linking to the selected collection's detail screen,
    /// routed value-based via `BooksRoute.collection`.
    private func collectionHeader(_ collection: BookCollection) -> some View {
        NavigationLink(value: BooksRoute.collection(collection)) {
            HStack(spacing: QuotesSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(QuotesColor.inkPrimary)
                        .lineLimit(1)
                    if let subtitle = collection.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(QuotesColor.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: QuotesSpacing.sm)
                HStack(spacing: 4) {
                    Text("컬렉션 보기")
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuotesColor.accent)
            }
            .padding(.horizontal, QuotesSpacing.md)
            .padding(.bottom, QuotesSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Collection chips (swipeable horizontal filter)

    private var collectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: QuotesSpacing.sm) {
                CollectionChip(
                    title: "전체",
                    isSelected: selectedCollectionId == nil
                ) { selectedCollectionId = nil }

                ForEach(collections) { collection in
                    CollectionChip(
                        title: collection.title,
                        isSelected: selectedCollectionId == collection.id
                    ) { selectedCollectionId = collection.id }
                }
            }
            .padding(.horizontal, QuotesSpacing.md)
            .padding(.vertical, QuotesSpacing.sm)
        }
    }

    // MARK: Cover gallery

    private var gallery: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: QuotesSpacing.md) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { idx, item in
                    // Value-based (Phase 3): a cover tap opens Book Detail, which
                    // in turn pushes the reader — all via `BooksRoute`.
                    NavigationLink(value: BooksRoute.bookDetail(item.book)) {
                        BookCoverView(
                            book: item.book,
                            representativeSentence: item.representativeSentence,
                            size: .grid
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            bookmarkBook(item.book)
                        } label: {
                            Label("책 북마크", systemImage: "book")
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

    // MARK: Data loading

    private func loadData() async {
        isLoading = true
        loadError = nil
        do {
            let loadedCollections = try await env.contentRepository.collections()
            var loadedItems: [BookCoverItem] = []
            for collection in loadedCollections {
                let books = try await env.contentRepository.books(in: collection.id)
                for book in books {
                    // Resolve the representative sentence caller-side, then inject.
                    let chunks = try? await env.contentRepository.chunks(bookId: book.id)
                    let sentence = chunks.flatMap(BookCoverContent.representativeSentence(from:))
                    loadedItems.append(
                        BookCoverItem(book: book, representativeSentence: sentence)
                    )
                }
            }
            collections = loadedCollections
            items = loadedItems
        } catch {
            loadError = error
        }
        isLoading = false
    }

    private func bookmarkBook(_ book: Book) {
        let bookmark = Bookmark(
            kind: .book,
            name: book.title,
            anchor: BookmarkAnchor(bookId: book.id)
        )
        env.bookmarks.add(bookmark)
    }
}

// MARK: - CollectionChip

/// Capsule filter chip for the 서재 collection selector.
private struct CollectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? QuotesColor.accent : QuotesColor.inkSecondary)
                .padding(.horizontal, QuotesSpacing.md)
                .padding(.vertical, QuotesSpacing.sm)
                .background(
                    isSelected ? QuotesColor.accentTint : QuotesColor.cardFill,
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? QuotesColor.accent.opacity(0.3) : QuotesColor.cardStroke,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
