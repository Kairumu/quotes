import SwiftUI

/// Sentence-per-row rendering: each sentence is a tappable row showing the
/// original text with its translation underneath (when enabled). Chunk titles
/// act as section headers. Supports tap-select, tap-to-extend, and
/// long-press-then-drag range selection.
struct SentenceModeView: View {
    let model: ReaderModel
    let selection: ReaderSelectionModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollViewReader { proxy in
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
            }
            .dragToSelect(model: model, selection: selection)
            .onChange(of: model.pendingScrollTarget) { _, target in
                scroll(proxy, to: target)
            }
            .onAppear { scroll(proxy, to: model.pendingScrollTarget) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to target: String?) {
        guard let target else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
            model.pendingScrollTarget = nil
        }
    }
}
