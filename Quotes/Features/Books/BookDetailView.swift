import SwiftUI

// MARK: - BookDetailView
//
// A palette-tinted book detail screen sitting between 서재/홈 and the reader.
// Kakao's "content is the UI" continues here: the book's `BookPalette` gradient
// tints the BACKGROUND only, while all text uses the warm ink colors for
// guaranteed contrast (light & dark).
//
// Reached exclusively via `BooksRoute.bookDetail(book)`; every push OUT of this
// screen (CTAs + chapter rows) is value-based `BooksRoute.reader(…)` so the
// Books stack stays 100% value-based and single-registration (see `BooksRoute`).
//
// UI-TEST HOOK: `.navigationTitle(book.title)` lets a UI test assert the detail
// nav bar by book title (Task 3.4).
struct BookDetailView: View {
    let book: Book
    @Environment(AppEnvironment.self) private var env

    /// Chunks loaded once for the representative sentence + chapter list.
    @State private var chunks: [Chunk] = []
    /// Saved reading position's sentence (if any) — powers 이어 읽기.
    @State private var resumeSentenceId: String?
    @State private var isLoading = true
    @State private var appeared = false

    private var palette: BookPalette.Token { BookPalette.token(for: book) }

    /// First sentence of the whole book, in the reader's canonical order. Used
    /// for 처음부터 (force top — passing `nil` would let the reader restore the
    /// saved position instead of opening at the beginning).
    private var firstSentenceId: String? {
        orderedChunks.first.flatMap { firstSentenceId(of: $0) }
    }

    /// One representative sentence (first sentence of the first chunk).
    private var representativeSentence: String? {
        BookCoverContent.representativeSentence(from: chunks)
    }

    private var orderedChunks: [Chunk] {
        chunks.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QuotesSpacing.lg) {
                hero
                ctaRow
                chapterList
            }
            .padding(.bottom, QuotesSpacing.xl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.35), value: appeared)
        }
        .background(QuotesColor.surfacePrimary.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadContent() }
        .onAppear { appeared = true }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.md) {
            Text(book.title)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(palette.heroInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(book.author)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(palette.heroInkSecondary)

            LanguageBadge(code: book.originalLanguage)

            Text(editorialIntro)
                .font(.system(.body, design: .serif))
                .foregroundStyle(palette.heroInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, QuotesSpacing.xs)

            if let sentence = representativeSentence, !sentence.isEmpty {
                Text("“\(sentence)”")
                    .font(.system(.headline, design: .serif))
                    .italic()
                    .foregroundStyle(palette.heroInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, QuotesSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QuotesSpacing.lg)
        .padding(.top, QuotesSpacing.md)
        .background(palette.backgroundGradient)
    }

    // MARK: CTA pair — [이어 읽기 | 처음부터]

    private var ctaRow: some View {
        HStack(spacing: QuotesSpacing.md) {
            // 이어 읽기 — resume at the saved sentence, or top if none.
            NavigationLink(value: BooksRoute.reader(
                BookDestination(book: book, sentenceId: resumeSentenceId ?? firstSentenceId)
            )) {
                ctaLabel(
                    title: "이어 읽기",
                    systemImage: "book.fill",
                    prominent: true
                )
            }
            .buttonStyle(.plain)

            // 처음부터 — force the top of the book.
            NavigationLink(value: BooksRoute.reader(
                BookDestination(book: book, sentenceId: firstSentenceId)
            )) {
                ctaLabel(
                    title: "처음부터",
                    systemImage: "arrow.up.to.line",
                    prominent: false
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, QuotesSpacing.lg)
    }

    private func ctaLabel(title: String, systemImage: String, prominent: Bool) -> some View {
        HStack(spacing: QuotesSpacing.sm) {
            Image(systemName: systemImage)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, QuotesSpacing.md)
        .foregroundStyle(prominent ? QuotesColor.surfacePrimary : QuotesColor.accent)
        .background(
            prominent ? AnyShapeStyle(QuotesColor.accent) : AnyShapeStyle(QuotesColor.accentTint),
            in: RoundedRectangle(cornerRadius: QuotesShape.cardCorner)
        )
        .overlay(
            RoundedRectangle(cornerRadius: QuotesShape.cardCorner)
                .strokeBorder(QuotesColor.accent.opacity(prominent ? 0 : 0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: Chapter list

    @ViewBuilder
    private var chapterList: some View {
        VStack(alignment: .leading, spacing: QuotesSpacing.sm) {
            Text("목차")
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuotesColor.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, QuotesSpacing.lg)

            if isLoading {
                ProgressView()
                    .tint(QuotesColor.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, QuotesSpacing.lg)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(orderedChunks.enumerated()), id: \.element.id) { idx, chunk in
                        chapterRow(index: idx, chunk: chunk)
                        if idx < orderedChunks.count - 1 {
                            Divider().padding(.leading, QuotesSpacing.lg)
                        }
                    }
                }
                .quotesCard()
                .padding(.horizontal, QuotesSpacing.lg)
            }
        }
    }

    private func chapterRow(index: Int, chunk: Chunk) -> some View {
        NavigationLink(value: BooksRoute.reader(
            BookDestination(book: book, sentenceId: firstSentenceId(of: chunk))
        )) {
            HStack(spacing: QuotesSpacing.md) {
                Text("\(index + 1)")
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(QuotesColor.accent)
                    .frame(width: 24, alignment: .center)

                Text(chunk.title ?? "\(index + 1)장")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(QuotesColor.inkPrimary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuotesColor.inkSecondary.opacity(0.5))
            }
            .padding(.horizontal, QuotesSpacing.md)
            .padding(.vertical, QuotesSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Content ordering helpers

    /// The first sentence id of a chunk, in the reader's canonical order
    /// (paragraphs by `order`, sentences by `order`).
    private func firstSentenceId(of chunk: Chunk) -> String? {
        chunk.paragraphs
            .sorted { $0.order < $1.order }
            .first?
            .sentences
            .sorted { $0.order < $1.order }
            .first?
            .id
    }

    // MARK: Editorial intro (hardcoded Korean copy, v1)

    private var editorialIntro: String {
        switch book.id {
        case "b001":
            return "느림을 부끄러워하지 않는 거북이와 자만에 빠진 토끼. 짧지만 오래 남는 우화가 꾸준함의 가치를 조용히 일깨웁니다."
        case "b002":
            return "여름의 노래와 겨울의 준비 사이에서, 개미와 베짱이는 오늘의 선택이 내일을 어떻게 바꾸는지 보여 줍니다."
        case "b003":
            return "로마 황제가 스스로에게 건넨 사유의 기록. 흔들리는 하루 속에서 마음을 다잡는 짧은 성찰들을 만나 보세요."
        default:
            return "한 문장 한 문장, 천천히 곱씹으며 읽어 보세요."
        }
    }

    // MARK: Loading

    private func loadContent() async {
        isLoading = true
        chunks = (try? await env.contentRepository.chunks(bookId: book.id)) ?? []
        resumeSentenceId = (try? env.positionStore.position(bookId: book.id))?.sentenceId
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        BookDetailView(
            book: Book(
                id: "b001",
                collectionId: "col-fables",
                title: "The Tortoise and the Hare",
                author: "Aesop",
                originalLanguage: "en",
                chunkIds: ["b001-c001", "b001-c002"],
                version: 1
            )
        )
        .environment(AppEnvironment.placeholder())
    }
}
