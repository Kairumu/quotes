import SwiftUI

/// Paragraph rendering: each paragraph flows as inline, per-sentence tappable
/// text (so highlights/selection stay sentence-granular) with the joined
/// translation shown underneath when enabled. Chunk titles are section headers.
struct ParagraphModeView: View {
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
                        paragraphBlock(paragraph, chunkId: chunk.id)
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

    @ViewBuilder
    private func paragraphBlock(_ paragraph: Paragraph, chunkId: String) -> some View {
        let sentences = paragraph.sentences.sorted { $0.order < $1.order }
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 3) {
                ForEach(sentences) { sentence in
                    chip(sentence, chunkId: chunkId)
                        .id(sentence.id)
                        .onAppear { model.noteVisibility(sentence.id, visible: true) }
                        .onDisappear { model.noteVisibility(sentence.id, visible: false) }
                }
            }
            if env.showTranslation {
                let translation = sentences
                    .compactMap { $0.translations[env.translationLanguage] }
                    .joined(separator: " ")
                if !translation.isEmpty {
                    HStack(alignment: .top, spacing: ReaderStyle.translationLeadingInset - ReaderStyle.translationRuleWidth) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(ReaderStyle.translationRuleColor)
                            .frame(width: ReaderStyle.translationRuleWidth)
                        Text(translation)
                            .font(ReaderStyle.translationFont)
                            .foregroundStyle(.secondary)
                            .lineSpacing(ReaderStyle.paragraphLineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ sentence: Sentence, chunkId: String) -> some View {
        let highlightColor: Color? = model.isHighlighted(sentence.id)
            ? HighlightPalette.color(forTag: model.highlightColorTag(for: sentence.id))
            : nil
        let selected = selection.isSelected(sentence.id)
        Text(sentence.text)
            .font(ReaderStyle.originalFont)
            .lineSpacing(ReaderStyle.paragraphLineSpacing)
            .padding(.vertical, 1)
            .padding(.horizontal, 2)
            .background(ReaderStyle.tint(highlightColor: highlightColor, selected: selected))
            .contentShape(Rectangle())
            .trackSentenceFrame(sentence.id)
            .onTapGesture {
                selection.handleTap(
                    sentence,
                    inChunk: chunkId,
                    ordered: model.orderedSentences(inChunk: chunkId)
                )
            }
    }
}
