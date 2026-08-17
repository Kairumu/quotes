import SwiftUI

/// A single sentence rendered as a tappable row: original serif text with an
/// optional translation underneath (quieter sans, with a thin leading accent
/// rule). Shared by sentence mode and page mode so tap-select, highlight tint,
/// and translations behave identically — and so the `Paginator` can mirror the
/// exact rendered geometry.
struct SentenceRowView: View {
    let sentence: Sentence
    let chunkId: String
    let model: ReaderModel
    let selection: ReaderSelectionModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let highlightColor: Color? = model.isHighlighted(sentence.id)
            ? HighlightPalette.color(forTag: model.highlightColorTag(for: sentence.id))
            : nil
        let selected = selection.isSelected(sentence.id)
        let language = env.effectiveLanguage(for: model.book)
        VStack(alignment: .leading, spacing: ReaderStyle.rowInternalSpacing) {
            if env.translationDisplay == .translationOnly {
                // Translation replaces the original — same fallback expression
                // and font as `Paginator.height(of:)` so pages don't overflow.
                Text(sentence.translations[language] ?? sentence.text)
                    .font(ReaderStyle.originalFont)
                    .lineSpacing(ReaderStyle.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(sentence.text)
                    .font(ReaderStyle.originalFont)
                    .lineSpacing(ReaderStyle.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if env.translationDisplay == .interleave,
                   let translation = sentence.translations[language] {
                    HStack(alignment: .top, spacing: ReaderStyle.translationLeadingInset - ReaderStyle.translationRuleWidth) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(ReaderStyle.translationRuleColor)
                            .frame(width: ReaderStyle.translationRuleWidth)
                        Text(translation)
                            .font(ReaderStyle.translationFont)
                            .foregroundStyle(.secondary)
                            .lineSpacing(ReaderStyle.lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, ReaderStyle.rowVerticalPadding)
        .padding(.horizontal, ReaderStyle.rowHorizontalPadding)
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
