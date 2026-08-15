import SwiftUI

struct CollectionDetailView: View {
    let collection: BookCollection
    @Environment(AppEnvironment.self) private var env
    /// Books paired with a preloaded representative sentence for their cover row.
    @State private var items: [BookCoverItem] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var appeared = false

    var body: some View {
        ZStack {
            QuotesColor.surfacePrimary.ignoresSafeArea()
            contentBody
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadBooks() }
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
                action: { Task { await loadBooks() } },
                actionLabel: "재시도"
            )
        } else if items.isEmpty {
            BrandedEmptyState(
                headline: "책이 없어요",
                subtext: "이 컬렉션에 책이 없습니다",
                systemImage: "book.closed"
            )
        } else {
            // DECISION: keep a `List` of large cover rows — `.swipeActions` work
            // ONLY inside a `List` (a `LazyVGrid` cannot host them), so the List
            // preserves the swipe-to-bookmark AND context-menu affordances.
            List(Array(items.enumerated()), id: \.element.id) { idx, item in
                let book = item.book
                // Value-based (Phase 3): a book row opens Book Detail via
                // `BooksRoute` (registered at the Books stack root in BooksTabView).
                NavigationLink(value: BooksRoute.bookDetail(book)) {
                    BookCoverRow(item: item)
                }
                .listRowBackground(QuotesColor.surfacePrimary)
                .listRowSeparatorTint(QuotesColor.cardStroke)
                .contextMenu {
                    Button {
                        bookmarkBook(book)
                    } label: {
                        Label("책 북마크", systemImage: "book")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        bookmarkBook(book)
                    } label: {
                        Label("북마크", systemImage: "book")
                    }
                    .tint(QuotesColor.accent)
                }
                .offset(y: appeared ? 0 : 12)
                .opacity(appeared ? 1 : 0)
                .animation(
                    .easeOut(duration: 0.3).delay(Double(idx) * 0.05),
                    value: appeared
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(QuotesColor.surfacePrimary)
            .onAppear { appeared = true }
        }
    }

    private func loadBooks() async {
        isLoading = true
        loadError = nil
        do {
            let books = try await env.contentRepository.books(in: collection.id)
            var loadedItems: [BookCoverItem] = []
            for book in books {
                // Resolve the representative sentence caller-side, then inject.
                let chunks = try? await env.contentRepository.chunks(bookId: book.id)
                let sentence = chunks.flatMap(BookCoverContent.representativeSentence(from:))
                loadedItems.append(BookCoverItem(book: book, representativeSentence: sentence))
            }
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

// MARK: - BookCoverRow

/// A large cover-forward list row: a compact living cover beside its metadata.
private struct BookCoverRow: View {
    let item: BookCoverItem

    var body: some View {
        HStack(alignment: .top, spacing: QuotesSpacing.md) {
            BookCoverView(
                book: item.book,
                representativeSentence: item.representativeSentence,
                size: .compact
            )
            .frame(width: 104)

            VStack(alignment: .leading, spacing: QuotesSpacing.xs) {
                Text(item.book.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(QuotesColor.inkPrimary)
                    .lineLimit(2)

                Text(item.book.author)
                    .font(.subheadline)
                    .foregroundStyle(QuotesColor.inkSecondary)
                    .lineLimit(1)

                LanguageBadge(code: item.book.originalLanguage)

                if let sentence = item.representativeSentence, !sentence.isEmpty {
                    Text(sentence)
                        .font(.system(.footnote, design: .serif))
                        .italic()
                        .foregroundStyle(QuotesColor.inkSecondary)
                        .lineLimit(3)
                        .padding(.top, QuotesSpacing.xs)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, QuotesSpacing.sm)
        .contentShape(Rectangle())
    }
}
