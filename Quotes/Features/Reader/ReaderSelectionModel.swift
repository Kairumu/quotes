import Observation

/// Sentence-range selection state for the reader.
///
/// v1 works at sentence granularity: `startOffset`/`endOffset` stay `nil`. A
/// selection lives entirely within a single chunk; the first tapped sentence is
/// the anchor and subsequent taps in the same chunk extend the range by order.
@MainActor
@Observable
final class ReaderSelectionModel {
    private(set) var selectionChunkId: String?
    private(set) var anchorSentenceId: String?
    private(set) var selectedIds: Set<String> = []

    var isActive: Bool { !selectedIds.isEmpty }

    /// Applies a tap on `sentence` within `chunkId`. `ordered` is the chunk's
    /// sentences in reading order (used to compute the extended range).
    func handleTap(_ sentence: Sentence, inChunk chunkId: String, ordered: [Sentence]) {
        // Tapping any selected sentence clears the whole selection.
        if selectedIds.contains(sentence.id) {
            clear()
            return
        }
        // Extend the range when there is an anchor in the same chunk.
        if let anchorId = anchorSentenceId,
           selectionChunkId == chunkId,
           let anchorIndex = ordered.firstIndex(where: { $0.id == anchorId }),
           let tappedIndex = ordered.firstIndex(where: { $0.id == sentence.id }) {
            let range = min(anchorIndex, tappedIndex)...max(anchorIndex, tappedIndex)
            selectedIds = Set(ordered[range].map { $0.id })
            return
        }
        // Otherwise start a fresh selection anchored at this sentence.
        selectionChunkId = chunkId
        anchorSentenceId = sentence.id
        selectedIds = [sentence.id]
    }

    /// Selects the contiguous range between `from` and `to` within `chunkId`
    /// (used by press-and-drag selection). `from` acts as the anchor so the
    /// range live-extends as the finger moves.
    func dragSelect(from startId: String, to currentId: String, inChunk chunkId: String, ordered: [Sentence]) {
        guard let startIndex = ordered.firstIndex(where: { $0.id == startId }),
              let currentIndex = ordered.firstIndex(where: { $0.id == currentId }) else { return }
        let range = min(startIndex, currentIndex)...max(startIndex, currentIndex)
        selectionChunkId = chunkId
        anchorSentenceId = startId
        selectedIds = Set(ordered[range].map { $0.id })
    }

    func isSelected(_ sentenceId: String) -> Bool {
        selectedIds.contains(sentenceId)
    }

    func clear() {
        selectionChunkId = nil
        anchorSentenceId = nil
        selectedIds = []
    }
}
