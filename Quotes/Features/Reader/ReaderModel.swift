import SwiftUI
import Observation

/// Loading + content state for a single book's reader.
///
/// Owns the loaded chunks, derived sentence indexes (for ordering, position
/// tracking and highlight rendering), and the visible-sentence set used to
/// persist the reading position. Highlight state is **not** stored here — it is
/// derived live from `env.bookmarks` on each access (no cache to invalidate). A
/// reference to the `AppEnvironment` is captured on `load` so the view layer can
/// call mutating operations without threading services through every row.
@MainActor
@Observable
final class ReaderModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    let book: Book
    let initialSentenceId: String?

    var loadState: LoadState = .loading
    private(set) var chunks: [Chunk] = []

    /// The sentence the user is scrolled to; drives `ScrollViewReader`.
    var pendingScrollTarget: String?

    // Derived indexes (built once per load).
    private(set) var sentencesByChunk: [String: [Sentence]] = [:]
    private var chunkIdBySentence: [String: String] = [:]
    private var globalIndexBySentence: [String: Int] = [:]

    // Carousel units (built once per load alongside the indexes). One logical
    // unit per screen for the 문장/문단 carousels; no text measurement.
    private(set) var sentenceUnits: [ReaderUnit] = []
    private(set) var paragraphUnits: [ReaderUnit] = []
    private var sentenceUnitIndexBySentence: [String: Int] = [:]
    private var paragraphUnitIndexBySentence: [String: Int] = [:]

    // Reading-position tracking.
    private var visibleSentenceIds: Set<String> = []
    private var positionSaveTask: Task<Void, Never>?

    /// In page mode, the first sentence of the currently visible page. Used as
    /// the reading position and page-bookmark anchor when the reader is paged.
    var pageFirstSentenceId: String?

    /// In-memory pagination cache, keyed by layout. Books are small so a full
    /// recompute is cheap; caching keeps flips/rotations instant.
    private var paginationCache: [LayoutKey: PaginatedBook] = [:]

    private var env: AppEnvironment?

    init(book: Book, initialSentenceId: String?) {
        self.book = book
        self.initialSentenceId = initialSentenceId
    }

    // MARK: Loading

    func load(env: AppEnvironment) async {
        self.env = env
        loadState = .loading
        do {
            let loaded = try await env.contentRepository.chunks(bookId: book.id)
            chunks = loaded
            buildIndexes(from: loaded)
            loadState = .loaded
            resolveInitialScrollTarget()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func buildIndexes(from chunks: [Chunk]) {
        var byChunk: [String: [Sentence]] = [:]
        var chunkOf: [String: String] = [:]
        var globalIndex: [String: Int] = [:]
        var running = 0
        for chunk in chunks.sorted(by: { $0.order < $1.order }) {
            let ordered = chunk.paragraphs
                .sorted { $0.order < $1.order }
                .flatMap { $0.sentences.sorted { $0.order < $1.order } }
            byChunk[chunk.id] = ordered
            for sentence in ordered {
                chunkOf[sentence.id] = chunk.id
                globalIndex[sentence.id] = running
                running += 1
            }
        }
        sentencesByChunk = byChunk
        chunkIdBySentence = chunkOf
        globalIndexBySentence = globalIndex
        buildUnits(from: chunks)
    }

    /// Builds the 문장/문단 carousel units and their sentence→index maps. One
    /// unit per sentence (문장) and per paragraph (문단); the owning chunk title
    /// rides only on that chunk's first unit so it renders once at the top.
    private func buildUnits(from chunks: [Chunk]) {
        var sUnits: [ReaderUnit] = []
        var pUnits: [ReaderUnit] = []
        var sIndex: [String: Int] = [:]
        var pIndex: [String: Int] = [:]

        for chunk in chunks.sorted(by: { $0.order < $1.order }) {
            let paragraphs = chunk.paragraphs.sorted { $0.order < $1.order }
            var isFirstParagraphUnit = true
            for paragraph in paragraphs {
                let sentences = paragraph.sentences.sorted { $0.order < $1.order }
                guard !sentences.isEmpty else { continue }
                pUnits.append(ReaderUnit(
                    id: paragraph.id,
                    chunkId: chunk.id,
                    title: isFirstParagraphUnit ? chunk.title : nil,
                    sentences: sentences
                ))
                let pUnitIndex = pUnits.count - 1
                for sentence in sentences { pIndex[sentence.id] = pUnitIndex }
                isFirstParagraphUnit = false
            }

            let ordered = byChunkSentences(chunk.id)
            for (i, sentence) in ordered.enumerated() {
                sUnits.append(ReaderUnit(
                    id: sentence.id,
                    chunkId: chunk.id,
                    title: i == 0 ? chunk.title : nil,
                    sentences: [sentence]
                ))
                sIndex[sentence.id] = sUnits.count - 1
            }
        }

        sentenceUnits = sUnits
        paragraphUnits = pUnits
        sentenceUnitIndexBySentence = sIndex
        paragraphUnitIndexBySentence = pIndex
    }

    private func byChunkSentences(_ chunkId: String) -> [Sentence] {
        sentencesByChunk[chunkId] ?? []
    }

    /// The carousel units for a granularity (built once per load).
    func units(for granularity: ReaderUnitGranularity) -> [ReaderUnit] {
        switch granularity {
        case .sentence: return sentenceUnits
        case .paragraph: return paragraphUnits
        }
    }

    /// The index of the unit containing `sentenceId` for a granularity, if any.
    func unitIndex(of sentenceId: String, granularity: ReaderUnitGranularity) -> Int? {
        switch granularity {
        case .sentence: return sentenceUnitIndexBySentence[sentenceId]
        case .paragraph: return paragraphUnitIndexBySentence[sentenceId]
        }
    }

    /// Chunks in reading order (paragraphs already sorted for rendering).
    var orderedChunks: [Chunk] {
        chunks.sorted { $0.order < $1.order }
    }

    func orderedSentences(inChunk chunkId: String) -> [Sentence] {
        sentencesByChunk[chunkId] ?? []
    }

    /// The chunk that owns `sentenceId`, if any.
    func chunkId(of sentenceId: String) -> String? {
        chunkIdBySentence[sentenceId]
    }

    // MARK: Pagination

    /// Paginated layout for `key`, computed once per layout and cached.
    func paginated(for key: LayoutKey) -> PaginatedBook {
        if let cached = paginationCache[key] { return cached }
        let result = Paginator.paginate(
            chunks: chunks,
            orderedSentences: { [weak self] in self?.orderedSentences(inChunk: $0) ?? [] },
            key: key
        )
        paginationCache[key] = result
        return result
    }

    private func resolveInitialScrollTarget() {
        if let initialSentenceId, chunkIdBySentence[initialSentenceId] != nil {
            pendingScrollTarget = initialSentenceId
            return
        }
        if let saved = try? env?.positionStore.position(bookId: book.id)?.sentenceId,
           chunkIdBySentence[saved] != nil {
            pendingScrollTarget = saved
        }
    }

    // MARK: Highlights (derived live from `env.bookmarks` — no stored cache)

    /// Whether `sentenceId` is covered by a highlight bookmark. Reads
    /// `env.bookmarks` on each call so SwiftUI `@Observable` tracking
    /// re-renders on any bookmark mutation — no manual invalidation.
    func isHighlighted(_ sentenceId: String) -> Bool {
        guard let env else { return false }
        return env.bookmarks.highlight(coveringSentence: sentenceId, in: book.id) != nil
    }

    /// The `colorTag` of the highlight covering `sentenceId`, if any (`nil`
    /// renders as the default amber tint). Derived live from `env.bookmarks`.
    func highlightColorTag(for sentenceId: String) -> String? {
        guard let env else { return nil }
        return env.bookmarks.highlight(coveringSentence: sentenceId, in: book.id)?.colorTag
    }

    // MARK: Reading position

    /// Records a sentence entering/leaving the viewport in **이어보기 (continuous)**
    /// mode only. The paged modes (문장/문단 carousels, 페이지) feed the reading
    /// position exclusively through `notePagePosition(firstSentenceId:)`; they do
    /// not call this. Kept continuous-only so `topmostVisibleSentenceId` reflects a
    /// single scrolling surface.
    func noteVisibility(_ sentenceId: String, visible: Bool) {
        if visible {
            visibleSentenceIds.insert(sentenceId)
        } else {
            visibleSentenceIds.remove(sentenceId)
        }
        schedulePositionSave()
    }

    private var topmostVisibleSentenceId: String? {
        visibleSentenceIds.min {
            (globalIndexBySentence[$0] ?? .max) < (globalIndexBySentence[$1] ?? .max)
        }
    }

    /// The sentence anchoring the current reading position. In paged modes
    /// (문장/문단/페이지 carousels) this is the first sentence of the visible
    /// page/unit; in 이어보기 it is the topmost visible sentence in the scroll view.
    var currentPositionSentenceId: String? {
        if env?.viewMode.isPaged == true, let pageFirst = pageFirstSentenceId {
            return pageFirst
        }
        return topmostVisibleSentenceId ?? pageFirstSentenceId
    }

    /// Reading progress in `0...1`, derived from the current reading position's
    /// global sentence index over the book's total sentence count.
    ///
    /// This is the reader's OWN model (it owns `globalIndexBySentence` and
    /// `currentPositionSentenceId`), so exposing this computed property here is
    /// legitimate — distinct from the Home hero, which must derive progress
    /// independently and must NOT reach into these private reader internals.
    var progressFraction: Double {
        let total = globalIndexBySentence.count
        guard total > 1 else { return total == 1 ? 1 : 0 }
        guard let id = currentPositionSentenceId,
              let index = globalIndexBySentence[id] else { return 0 }
        return min(1, max(0, Double(index) / Double(total - 1)))
    }

    /// Records the first sentence of the visible page (page mode) and persists.
    func notePagePosition(firstSentenceId: String?) {
        pageFirstSentenceId = firstSentenceId
        schedulePositionSave()
    }

    private func schedulePositionSave() {
        positionSaveTask?.cancel()
        positionSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.persistPosition()
        }
    }

    func persistPosition() {
        guard let env,
              let topId = currentPositionSentenceId,
              let chunkId = chunkIdBySentence[topId] else { return }
        let position = ReadingPosition(
            bookId: book.id,
            chunkId: chunkId,
            sentenceId: topId,
            viewMode: env.viewMode
        )
        try? env.positionStore.save(position)
    }

    // MARK: Bookmark creation

    /// Selected sentences of the active selection, in reading order.
    func selectedSentences(_ selection: ReaderSelectionModel) -> [Sentence] {
        guard let chunkId = selection.selectionChunkId else { return [] }
        return orderedSentences(inChunk: chunkId).filter { selection.selectedIds.contains($0.id) }
    }

    @discardableResult
    func createHighlight(
        from selection: ReaderSelectionModel,
        colorTag: String? = nil,
        emojiTag: String? = nil
    ) -> Bookmark? {
        guard let env,
              let chunkId = selection.selectionChunkId else { return nil }
        let sentences = selectedSentences(selection)
        guard let first = sentences.first else { return nil }
        let name = String(first.text.prefix(20)) + "…"
        let bookmark = Bookmark(
            kind: .highlight,
            name: name,
            anchor: BookmarkAnchor(
                bookId: book.id,
                chunkId: chunkId,
                sentenceIds: sentences.map { $0.id }
            ),
            colorTag: colorTag,
            emojiTag: emojiTag
        )
        env.bookmarks.add(bookmark)
        return bookmark
    }

    // MARK: Highlight removal (B1)

    /// Highlights of the current book whose anchor sentences intersect the
    /// active selection. Empty when the selection touches no highlight.
    func highlightsIntersecting(_ selection: ReaderSelectionModel) -> [Bookmark] {
        guard let env, !selection.selectedIds.isEmpty else { return [] }
        let selected = selection.selectedIds
        return env.bookmarks.highlights(bookId: book.id).filter { bookmark in
            !Set(bookmark.anchor.sentenceIds).isDisjoint(with: selected)
        }
    }

    /// Removes every highlight intersecting the selection.
    ///
    /// LOCKED v1 rule: a partial overlap removes the WHOLE highlight bookmark —
    /// there is no offset-level range splitting (offsets are `nil` in v1). If a
    /// selection touches even one sentence of a multi-sentence highlight, the
    /// entire highlight is deleted.
    func removeHighlights(intersecting selection: ReaderSelectionModel) {
        guard let env else { return }
        let ids = Set(highlightsIntersecting(selection).map { $0.id })
        guard !ids.isEmpty else { return }
        env.bookmarks.delete(ids: ids)
    }

    /// Creates a capture bookmark and returns it together with the selected
    /// sentences the caller should render into a capture card.
    func createCapture(from selection: ReaderSelectionModel) -> (bookmark: Bookmark, sentences: [Sentence])? {
        guard let env,
              let chunkId = selection.selectionChunkId else { return nil }
        let sentences = selectedSentences(selection)
        guard !sentences.isEmpty else { return nil }
        let bookmark = Bookmark(
            kind: .capture,
            name: "캡처 – \(book.title)",
            anchor: BookmarkAnchor(
                bookId: book.id,
                chunkId: chunkId,
                sentenceIds: sentences.map { $0.id }
            )
        )
        env.bookmarks.add(bookmark)
        return (bookmark, sentences)
    }

    @discardableResult
    func createPageBookmark() -> Bookmark? {
        guard let env,
              let topId = currentPositionSentenceId,
              let chunkId = chunkIdBySentence[topId] else { return nil }
        let chunkTitle = orderedChunks.first { $0.id == chunkId }?.title
        let name = chunkTitle.map { "\(book.title) – \($0)" } ?? book.title
        let bookmark = Bookmark(
            kind: .page,
            name: name,
            anchor: BookmarkAnchor(
                bookId: book.id,
                chunkId: chunkId,
                sentenceIds: [topId]
            )
        )
        env.bookmarks.add(bookmark)
        return bookmark
    }

    @discardableResult
    func createBookBookmark() -> Bookmark? {
        guard let env else { return nil }
        let bookmark = Bookmark(
            kind: .book,
            name: book.title,
            anchor: BookmarkAnchor(bookId: book.id)
        )
        env.bookmarks.add(bookmark)
        return bookmark
    }

    func applyRename(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let env, !trimmed.isEmpty else { return }
        env.bookmarks.rename(id: id, to: trimmed)
    }
}
