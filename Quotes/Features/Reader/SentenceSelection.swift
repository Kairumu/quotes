import SwiftUI

/// Collects per-sentence frames (in the reader selection coordinate space) so a
/// drag gesture can map a finger location to the sentence underneath it.
struct SentenceFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Publishes this view's frame for `sentenceId` in the shared selection
    /// coordinate space, used by drag-to-select hit testing.
    func trackSentenceFrame(_ sentenceId: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SentenceFramePreferenceKey.self,
                    value: [sentenceId: proxy.frame(in: .named(ReaderStyle.selectionSpace))]
                )
            }
        )
    }
}

/// Hosts long-press-then-drag selection over sentence rows.
///
/// Attach around a scrolling container of sentence rows. Rows must publish their
/// frames via `trackSentenceFrame(_:)`. A deliberate long press is required
/// before dragging so normal scrolling is never hijacked.
struct DragSelectModifier: ViewModifier {
    let model: ReaderModel
    let selection: ReaderSelectionModel

    @State private var frames: [String: CGRect] = [:]
    @State private var dragStartSentenceId: String?

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: ReaderStyle.selectionSpace)
            .onPreferenceChange(SentenceFramePreferenceKey.self) { frames = $0 }
            .gesture(dragSelectGesture)
    }

    private var dragSelectGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(ReaderStyle.selectionSpace)))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                guard let hitId = sentenceId(at: drag.location) else { return }
                if dragStartSentenceId == nil {
                    dragStartSentenceId = hitId
                }
                guard let startId = dragStartSentenceId,
                      let chunkId = model.chunkId(of: startId) else { return }
                // Keep the range within the starting sentence's chunk.
                guard model.chunkId(of: hitId) == chunkId else { return }
                selection.dragSelect(
                    from: startId,
                    to: hitId,
                    inChunk: chunkId,
                    ordered: model.orderedSentences(inChunk: chunkId)
                )
            }
            .onEnded { _ in dragStartSentenceId = nil }
    }

    /// Finds the sentence under `point`: prefers a frame that contains it,
    /// otherwise falls back to the vertically nearest frame (so dragging into
    /// the gaps or past the ends still extends the selection).
    private func sentenceId(at point: CGPoint) -> String? {
        if let hit = frames.first(where: { $0.value.contains(point) })?.key {
            return hit
        }
        return frames.min { lhs, rhs in
            verticalDistance(from: point, to: lhs.value) < verticalDistance(from: point, to: rhs.value)
        }?.key
    }

    private func verticalDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        if point.y < rect.minY { return rect.minY - point.y }
        if point.y > rect.maxY { return point.y - rect.maxY }
        return 0
    }
}

extension View {
    /// Enables long-press-then-drag range selection over sentence rows.
    func dragToSelect(model: ReaderModel, selection: ReaderSelectionModel) -> some View {
        modifier(DragSelectModifier(model: model, selection: selection))
    }
}
