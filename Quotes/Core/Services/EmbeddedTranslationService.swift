import Foundation

/// Translation service backed by the pre-embedded translations in each `Chunk`.
///
/// v1 sample content ships Korean (`ko`) translations for every sentence inside the
/// chunk JSON. `availableLanguages(bookId:)` discovers the supported language codes
/// by inspecting the `translations` dictionary of the first sentence in the first
/// chunk. This avoids hard-coding the language list and automatically adapts when
/// new languages are added to the JSON.
///
/// `ensureTranslations(bookId:chunkId:language:)` is a no-op for languages that are
/// already embedded, and throws `ContentError.notFound` for unavailable languages so
/// the caller knows not to attempt display.
///
/// - Note: A future `FirestoreTranslationService` would call the `translateChunk`
///   Cloud Function to generate translations on demand, cache the results in
///   Firestore under `books/{bookId}/chunks/{chunkId}`, and return them through
///   this same `TranslationService` protocol so callers require no changes.
public final class EmbeddedTranslationService: TranslationService, @unchecked Sendable {

    private let contentRepository: any ContentRepository

    public init(contentRepository: any ContentRepository) {
        self.contentRepository = contentRepository
    }

    // MARK: - TranslationService

    public func availableLanguages(bookId: String) async -> [String] {
        guard
            let firstChunk = try? await contentRepository.chunks(bookId: bookId).first,
            let firstSentence = firstChunk.paragraphs.first?.sentences.first,
            !firstSentence.translations.isEmpty
        else {
            return ["ko"]
        }
        return Array(firstSentence.translations.keys).sorted()
    }

    public func ensureTranslations(bookId: String, chunkId: String, language: String) async throws {
        let languages = await availableLanguages(bookId: bookId)
        guard languages.contains(language) else {
            throw ContentError.notFound(language)
        }
        // Translations are already embedded in the chunk JSON — nothing to fetch.
    }
}
