import Foundation

/// Provides per-sentence translations.
///
/// v1 sample content ships with embedded translations, so `ensureTranslations`
/// is a no-op for bundled books. The protocol exists so a future Firestore/LLM
/// path can fetch or generate translations on demand.
public protocol TranslationService: Sendable {
    /// Language codes for which translations exist for the given book.
    func availableLanguages(bookId: String) async -> [String]
    /// Ensure translations for a chunk in a language are available, fetching or
    /// generating them if necessary. No-op when already present.
    func ensureTranslations(bookId: String, chunkId: String, language: String) async throws
}
