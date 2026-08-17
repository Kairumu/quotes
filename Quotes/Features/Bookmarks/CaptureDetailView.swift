import SwiftUI
import UIKit

/// Shows the stored capture as a live CaptureCardView and provides a ShareLink
/// that renders the card at 3× via ImageRenderer on demand — nothing is stored
/// as a bitmap; the image is always re-derived from the anchor's sentence IDs.
public struct CaptureDetailView: View {
    let bookmark: Bookmark
    @Environment(AppEnvironment.self) private var env

    @State private var sentences: [Sentence] = []
    @State private var book: Book?
    @State private var renderedImage: Image?
    @State private var isLoading = true

    public init(bookmark: Bookmark) {
        self.bookmark = bookmark
    }

    public var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let book, !sentences.isEmpty {
                VStack(spacing: 20) {
                    CaptureCardView(
                        sentences: sentences,
                        book: book,
                        displayMode: env.translationDisplay,
                        translationLanguage: env.effectiveLanguage(for: book)
                    )
                    .padding(.horizontal)

                    if let image = renderedImage {
                        ShareLink(
                            item: image,
                            preview: SharePreview(bookmark.name, image: image)
                        ) {
                            Label("공유하기", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 24)
            } else {
                ContentUnavailableView(
                    "내용을 불러올 수 없어요",
                    systemImage: "exclamationmark.triangle",
                    description: Text("캡처에 연결된 문장을 찾을 수 없습니다.")
                )
                .padding(.top, 80)
            }
        }
        .navigationTitle(bookmark.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: Data loading

    @MainActor
    private func loadData() async {
        guard let bookId = bookmark.anchor.bookId else {
            isLoading = false
            return
        }

        let repo = env.contentRepository

        do {
            async let bookFetch = repo.book(id: bookId)
            async let chunksFetch = repo.chunks(bookId: bookId)
            let (loadedBook, chunks) = try await (bookFetch, chunksFetch)

            let anchorIds = Set(bookmark.anchor.sentenceIds)
            var found: [Sentence] = []
            for chunk in chunks {
                for para in chunk.paragraphs {
                    for sentence in para.sentences where anchorIds.contains(sentence.id) {
                        found.append(sentence)
                    }
                }
            }

            // Preserve the anchor's sentence ordering
            let orderMap = Dictionary(
                uniqueKeysWithValues: bookmark.anchor.sentenceIds.enumerated().map { ($1, $0) }
            )
            found.sort { (orderMap[$0.id] ?? 0) < (orderMap[$1.id] ?? 0) }

            self.book = loadedBook
            self.sentences = found

            if !found.isEmpty {
                renderImage(sentences: found, book: loadedBook)
            }
        } catch {
            // Fall through to empty state
        }

        isLoading = false
    }

    // MARK: Image rendering

    @MainActor
    private func renderImage(sentences: [Sentence], book: Book) {
        let card = CaptureCardView(
            sentences: sentences,
            book: book,
            displayMode: env.translationDisplay,
            translationLanguage: env.effectiveLanguage(for: book)
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}

#Preview {
    let anchor = BookmarkAnchor(bookId: "b001", chunkId: "b001-c001", sentenceIds: ["b001-c001-p001-s001"])
    let bookmark = Bookmark(kind: .capture, name: "미리보기 캡처", anchor: anchor)
    return NavigationStack {
        CaptureDetailView(bookmark: bookmark)
            .environment(AppEnvironment.placeholder())
    }
}
