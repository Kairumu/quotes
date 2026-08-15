import SwiftUI

struct CollectionDetailView: View {
    let collection: BookCollection
    @Environment(AppEnvironment.self) private var env
    @State private var books: [Book] = []
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
        } else if books.isEmpty {
            BrandedEmptyState(
                headline: "책이 없어요",
                subtext: "이 컬렉션에 책이 없습니다",
                systemImage: "book.closed"
            )
        } else {
            List(Array(books.enumerated()), id: \.element.id) { idx, book in
                NavigationLink {
                    ReaderScreen(book: book)
                } label: {
                    BookRowView(book: book)
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
            books = try await env.contentRepository.books(in: collection.id)
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
