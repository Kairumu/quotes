import Foundation
import Observation

// MARK: - ContentOrdering
//
// The canonical reading order for a book's sentences: chunks by `order`, then
// paragraphs by `order`, then sentences by `order`. Factored into a small shared
// helper so the 홈 feed (HomeModel) can derive progress index/total INDEPENDENTLY
// of the reader — it does NOT reach into `ReaderModel.globalIndexBySentence`
// (which is `private` and reader-only). Same ordering rule, no shared state.

enum ContentOrdering {
    /// All sentences of a book in canonical reading order.
    static func orderedSentences(chunks: [Chunk]) -> [Sentence] {
        chunks
            .sorted { $0.order < $1.order }
            .flatMap { $0.paragraphs.sorted { $0.order < $1.order } }
            .flatMap { $0.sentences.sorted { $0.order < $1.order } }
    }

    /// All sentence IDs of a book in canonical reading order.
    static func orderedSentenceIds(chunks: [Chunk]) -> [String] {
        orderedSentences(chunks: chunks).map { $0.id }
    }
}

// MARK: - Feed value types

/// A sentence flattened out of the content tree, paired with its owning book.
/// Powers the 오늘의 문장 pool (deterministic daily pick over all sentences).
struct PooledSentence: Identifiable, Hashable {
    let sentence: Sentence
    let book: Book
    var id: String { sentence.id }
    var text: String { sentence.text }
}

/// The resolved 이어 읽기 target: the most-recently-read book plus everything the
/// hero needs, all derived from the shared load (no reader internals).
struct ContinueReadingTarget: Hashable {
    let book: Book
    let sentenceId: String
    let sentenceText: String
    /// 1-based sentence position for display (e.g. "42 / 130").
    let sentenceNumber: Int
    let totalCount: Int
    /// Reading progress in `0...1`.
    let progress: Double
}

// MARK: - HomeModel
//
// A3 (mandated): ONE shared loader for the entire 홈 feed. It loads
// collections → books → chunks EXACTLY ONCE and every block (이어 읽기 hero,
// 오늘의 문장, collections carousel, 내 하이라이트 carousel) reads from this single
// model — never a per-block load.
//
// A2 (staleness): `ReadingPositionStore` is NOT observable and `TabView` keeps
// 홈 alive, so a one-shot `.task` read would leave the hero frozen after the user
// reads (same bug class as the previously-fixed stale bookmark count). Chosen
// strategy: `HomeTabView` calls `refreshContinueReading()` on EVERY `.onAppear`
// of the 홈 tab, re-reading `allPositions()` and re-resolving the hero.

@MainActor
@Observable
final class HomeModel {

    // MARK: Loaded content (populated once by `load()`)

    private(set) var collections: [BookCollection] = []
    private(set) var books: [Book] = []
    /// Flattened sentence pool across all books, in per-book reading order.
    private(set) var sentencePool: [PooledSentence] = []
    /// Resolved 이어 읽기 target; `nil` when there is no reading history.
    private(set) var continueReading: ContinueReadingTarget?

    private(set) var isLoaded = false
    private(set) var loadError: Error?

    // MARK: Derived lookups (built during `load()`)

    private var booksById: [String: Book] = [:]
    /// Per-book canonical sentence-id order (for index/total math).
    private var orderedSentenceIdsByBook: [String: [String]] = [:]
    /// Global sentence-id → text map (resolves saved positions & highlights).
    private var sentenceTextById: [String: String] = [:]

    // MARK: Dependencies

    private let contentRepository: any ContentRepository
    private let positionStore: any ReadingPositionStore

    init(contentRepository: any ContentRepository, positionStore: any ReadingPositionStore) {
        self.contentRepository = contentRepository
        self.positionStore = positionStore
    }

    // MARK: - Single load (A3)

    /// Load the whole content tree once and build every lookup the feed needs.
    /// Idempotent-ish: safe to call again (e.g. after an error); it rebuilds.
    func load() async {
        loadError = nil
        do {
            let loadedCollections = try await contentRepository.collections()

            var loadedBooks: [Book] = []
            var pool: [PooledSentence] = []
            var orderedIds: [String: [String]] = [:]
            var textById: [String: String] = [:]

            for collection in loadedCollections {
                let booksInCollection = try await contentRepository.books(in: collection.id)
                for book in booksInCollection {
                    loadedBooks.append(book)
                    let chunks = (try? await contentRepository.chunks(bookId: book.id)) ?? []
                    let ordered = ContentOrdering.orderedSentences(chunks: chunks)
                    orderedIds[book.id] = ordered.map { $0.id }
                    for sentence in ordered {
                        textById[sentence.id] = sentence.text
                        pool.append(PooledSentence(sentence: sentence, book: book))
                    }
                }
            }

            collections = loadedCollections
            books = loadedBooks
            booksById = Dictionary(uniqueKeysWithValues: loadedBooks.map { ($0.id, $0) })
            orderedSentenceIdsByBook = orderedIds
            sentenceTextById = textById
            sentencePool = pool
            isLoaded = true

            refreshContinueReading()
        } catch {
            loadError = error
        }
    }

    // MARK: - Continue-reading refresh (A2)

    /// Re-read all saved positions and re-resolve the 이어 읽기 hero. Called on every
    /// 홈 `.onAppear` because the position store is not observable — this is what
    /// keeps the hero fresh after the user reads and returns to 홈.
    func refreshContinueReading() {
        guard isLoaded else { return }
        guard
            let positions = try? positionStore.allPositions(),
            let recent = positions.max(by: { $0.updatedAt < $1.updatedAt }),
            let book = booksById[recent.bookId]
        else {
            continueReading = nil
            return
        }
        continueReading = makeTarget(book: book, position: recent)
    }

    /// Derive the hero's progress index/total INDEPENDENTLY from the shared load
    /// (C4 — no dependency on `ReaderModel` privates).
    private func makeTarget(book: Book, position: ReadingPosition) -> ContinueReadingTarget {
        let ordered = orderedSentenceIdsByBook[book.id] ?? []
        let total = ordered.count
        let zeroBasedIndex = ordered.firstIndex(of: position.sentenceId) ?? 0
        let progress = total > 0 ? Double(zeroBasedIndex + 1) / Double(total) : 0
        let text = sentenceTextById[position.sentenceId] ?? ""
        return ContinueReadingTarget(
            book: book,
            sentenceId: position.sentenceId,
            sentenceText: text,
            sentenceNumber: total > 0 ? zeroBasedIndex + 1 : 0,
            totalCount: total,
            progress: progress
        )
    }

    // MARK: - 오늘의 문장 (deterministic daily pick)

    /// The sentence shown all day, picked deterministically by day-of-year over
    /// the shared pool. Stable within a day, changes across days.
    var dailyQuote: PooledSentence? {
        let seed = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return dailyQuote(daySeed: seed)
    }

    /// Testable / preview-overridable variant of `dailyQuote`.
    func dailyQuote(daySeed seed: Int) -> PooledSentence? {
        guard !sentencePool.isEmpty else { return nil }
        let index = ((seed % sentencePool.count) + sentencePool.count) % sentencePool.count
        return sentencePool[index]
    }

    // MARK: - Lookups for other blocks

    /// The book owning a bookmark's anchor, if loaded.
    func book(id: String) -> Book? { booksById[id] }

    /// Resolve a highlight's display text from the shared sentence map, joining
    /// its anchored sentences in order. Falls back to the bookmark's name.
    func highlightText(for bookmark: Bookmark) -> String {
        let joined = bookmark.anchor.sentenceIds
            .compactMap { sentenceTextById[$0] }
            .joined(separator: " ")
        return joined.isEmpty ? bookmark.name : joined
    }
}
