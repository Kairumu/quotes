import SwiftUI

/// Sentence-per-row rendering: each sentence is a tappable row showing the
/// original text with its translation underneath (when enabled). Chunk titles
/// act as section headers. Supports tap-select, tap-to-extend, and
/// long-press-then-drag range selection.
struct SentenceModeView: View {
    let model: ReaderModel
    let selection: ReaderSelectionModel
    @Environment(AppEnvironment.self) private var env
    // Data-driven scroll position: unlike ScrollViewReader.scrollTo, this works
    // for rows a LazyVStack has not instantiated yet (e.g. bookmark deep links
    // far down the book).
    @State private var scrolledSentenceId: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ReaderStyle.rowSpacing) {
                ForEach(model.orderedChunks) { chunk in
                    if let title = chunk.title {
                        Text(title)
                            .font(.title3.bold())
                            .padding(.top, ReaderStyle.titleTopPadding)
                            .padding(.bottom, ReaderStyle.titleBottomPadding)
                            .padding(.horizontal, ReaderStyle.rowHorizontalPadding)
                    }
                    ForEach(model.orderedSentences(inChunk: chunk.id)) { sentence in
                        SentenceRowView(
                            sentence: sentence,
                            chunkId: chunk.id,
                            model: model,
                            selection: selection
                        )
                        .id(sentence.id)
                        .onAppear { model.noteVisibility(sentence.id, visible: true) }
                        .onDisappear { model.noteVisibility(sentence.id, visible: false) }
                    }
                }
            }
            .padding(.vertical, 12)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledSentenceId, anchor: .top)
        .dragToSelect(model: model, selection: selection)
        .onChange(of: model.pendingScrollTarget) { _, target in
            scroll(to: target)
        }
        .onAppear { scroll(to: model.pendingScrollTarget) }
    }

    private func scroll(to target: String?) {
        guard let target else { return }
        scrolledSentenceId = target
        model.pendingScrollTarget = nil
    }
}
