import SwiftUI

/// Renders one paragraph as per-sentence, tappable flow chips honouring the
/// 3-way translation display (원문만/병기/번역만). Shared by 이어보기
/// (`ContinuousModeView`) and the 문단 carousel (`UnitCarouselView`) so
/// tap-select, highlight/selection tint, and translation rendering stay
/// byte-identical across the two surfaces.
///
/// - 원문만 → an original chip per sentence.
/// - 병기 → each original chip is followed by an inline translation chip that
///   shares the sentence's tap target and tint.
/// - 번역만 → the chip text is swapped to the translation (original font),
///   falling back to the original text when a translation is missing.
struct ParagraphFlowBlock: View {
    let sentences: [Sentence]
    let chunkId: String
    let model: ReaderModel
    let selection: ReaderSelectionModel
    /// When true (이어보기, a single scrolling surface) each chip reports its
    /// viewport visibility to drive the reading position. The 문단 carousel
    /// passes `false` — it feeds `notePagePosition` from the visible unit index.
    var tracksVisibility: Bool = false
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let ordered = sentences.sorted { $0.order < $1.order }
        let language = env.effectiveLanguage(for: model.book)
        FlowLayout(spacing: 3) {
            ForEach(ordered) { sentence in
                chip(sentence, language: language)
                    .id(sentence.id)
                    .onAppear { if tracksVisibility { model.noteVisibility(sentence.id, visible: true) } }
                    .onDisappear { if tracksVisibility { model.noteVisibility(sentence.id, visible: false) } }
                if env.translationDisplay == .interleave,
                   let translation = sentence.translations[language] {
                    translationChip(translation, for: sentence)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ sentence: Sentence, language: String) -> some View {
        let highlightColor: Color? = model.isHighlighted(sentence.id)
            ? HighlightPalette.color(forTag: model.highlightColorTag(for: sentence.id))
            : nil
        let selected = selection.isSelected(sentence.id)
        let text = env.translationDisplay == .translationOnly
            ? (sentence.translations[language] ?? sentence.text)
            : sentence.text
        Text(text)
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

    /// Inline translation chip shown after its original chip in 병기 mode. Shares
    /// the sentence's tap target and highlight/selection tint.
    @ViewBuilder
    private func translationChip(_ translation: String, for sentence: Sentence) -> some View {
        let highlightColor: Color? = model.isHighlighted(sentence.id)
            ? HighlightPalette.color(forTag: model.highlightColorTag(for: sentence.id))
            : nil
        let selected = selection.isSelected(sentence.id)
        Text(translation)
            .font(ReaderStyle.translationFont)
            .foregroundStyle(.secondary)
            .lineSpacing(ReaderStyle.paragraphLineSpacing)
            .padding(.vertical, 1)
            .padding(.horizontal, 2)
            .background(ReaderStyle.tint(highlightColor: highlightColor, selected: selected))
            .contentShape(Rectangle())
            .onTapGesture {
                selection.handleTap(
                    sentence,
                    inChunk: chunkId,
                    ordered: model.orderedSentences(inChunk: chunkId)
                )
            }
    }
}
