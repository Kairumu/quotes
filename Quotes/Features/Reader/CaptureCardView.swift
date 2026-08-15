import SwiftUI

/// A styled passage card used both for share-sheet capture images and for
/// re-rendering saved captures in the My tab.
///
/// Renders the selected original sentences with optional translations and a
/// book title/author footer. Designed to be rasterised with `ImageRenderer`.
public struct CaptureCardView: View {
    private let sentences: [Sentence]
    private let book: Book
    private let showTranslation: Bool
    private let translationLanguage: String

    public init(
        sentences: [Sentence],
        book: Book,
        showTranslation: Bool,
        translationLanguage: String
    ) {
        self.sentences = sentences
        self.book = book
        self.showTranslation = showTranslation
        self.translationLanguage = translationLanguage
    }

    private var originalText: String {
        sentences.map { $0.text }.joined(separator: " ")
    }

    private var translatedText: String {
        sentences.compactMap { $0.translations[translationLanguage] }.joined(separator: " ")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(originalText)
                .font(ReaderStyle.cardOriginalFont)
                .foregroundStyle(.primary)
                .lineSpacing(ReaderStyle.paragraphLineSpacing)
                .fixedSize(horizontal: false, vertical: true)

            if showTranslation, !translatedText.isEmpty {
                Text(translatedText)
                    .font(ReaderStyle.translationFont)
                    .foregroundStyle(.secondary)
                    .lineSpacing(ReaderStyle.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.headline)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
