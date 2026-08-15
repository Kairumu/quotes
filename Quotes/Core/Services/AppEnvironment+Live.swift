import Foundation
import SwiftData

public extension AppEnvironment {

    /// The production `AppEnvironment` wired to on-disk SwiftData persistence and
    /// bundled JSON content.
    ///
    /// Usage (integration phase — do NOT edit `QuotesApp` from this worker):
    /// ```swift
    /// let container = try PersistenceSchema.container()
    /// let env = AppEnvironment.live(modelContainer: container)
    /// ```
    ///
    /// Upgrade path: swap individual dependencies here without touching feature code.
    /// - `LocalJSONContentRepository` → `FirestoreContentRepository`
    /// - `EmbeddedTranslationService`  → `FirestoreTranslationService` (calls `translateChunk` Cloud Function)
    /// - SwiftData stores remain until a Firestore sync layer is added.
    @MainActor
    static func live(modelContainer: ModelContainer) -> AppEnvironment {
        let contentRepository = LocalJSONContentRepository()
        let translationService = EmbeddedTranslationService(contentRepository: contentRepository)
        let bookmarkStore = SwiftDataBookmarkStore(modelContainer: modelContainer)
        let positionStore = SwiftDataReadingPositionStore(modelContainer: modelContainer)

        return AppEnvironment(
            contentRepository: contentRepository,
            translationService: translationService,
            bookmarkStore: bookmarkStore,
            positionStore: positionStore
        )
    }
}
