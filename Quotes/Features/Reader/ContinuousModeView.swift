import SwiftUI

/// 이어보기 (continuous): the whole book flows in one vertical scroll, each
/// paragraph rendered as per-sentence tappable flow chips (so highlights and
/// selection stay sentence-granular) honouring the 3-way translation display.
/// Chunk titles are section headers. Chrome hides/shows on scroll hysteresis and
/// full long-press drag-select is available.
///
/// Formerly `ParagraphModeView`; repurposed as the continuous mode when the 문단
/// slot moved to the `UnitCarouselView` paragraph carousel. Presentation is
/// unchanged — only the mode it backs.
struct ContinuousModeView: View {
    let model: ReaderModel
    let selection: ReaderSelectionModel
    /// Shared immersive-chrome flag: scroll-driven hide/show in this mode.
    @Binding var chromeHidden: Bool
    @Environment(AppEnvironment.self) private var env

    // Data-driven scroll position at PARAGRAPH granularity: sentence chips sit
    // inside FlowLayout (not direct scroll-target children), and LazyVStack
    // never registers un-instantiated anchors with ScrollViewReader — so we
    // scroll to the paragraph block containing the target sentence instead.
    @State private var scrolledParagraphId: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(model.orderedChunks) { chunk in
                    if let title = chunk.title {
                        Text(title)
                            .font(.title3.bold())
                            .padding(.top, 20)
                    }
                    ForEach(chunk.paragraphs.sorted { $0.order < $1.order }) { paragraph in
                        ParagraphFlowBlock(
                            sentences: paragraph.sentences,
                            chunkId: chunk.id,
                            model: model,
                            selection: selection,
                            tracksVisibility: true
                        )
                        .id(paragraph.id)
                    }
                }
            }
            .padding(20)
            .scrollTargetLayout()
            .trackReaderScrollOffset()
        }
        .scrollPosition(id: $scrolledParagraphId, anchor: .top)
        .dragToSelect(model: model, selection: selection)
        .readerChromeHide(chromeHidden: $chromeHidden)
        .onChange(of: model.pendingScrollTarget) { _, target in
            scroll(to: target)
        }
        .onAppear { scroll(to: model.pendingScrollTarget) }
    }

    private func scroll(to target: String?) {
        guard let target else { return }
        if let paragraphId = paragraphId(containing: target) {
            scrolledParagraphId = paragraphId
        }
        model.pendingScrollTarget = nil
    }

    private func paragraphId(containing sentenceId: String) -> String? {
        for chunk in model.orderedChunks {
            for paragraph in chunk.paragraphs
            where paragraph.sentences.contains(where: { $0.id == sentenceId }) {
                return paragraph.id
            }
        }
        return nil
    }
}
