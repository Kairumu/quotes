import Foundation
import Observation

/// The app-wide dependency container and reader display settings.
///
/// Injected into the SwiftUI view hierarchy via `.environment(...)`. Feature
/// code reads services and settings from here. Marked `@MainActor` because it
/// drives UI state and is mutated from the main thread.
@MainActor
@Observable
public final class AppEnvironment {
    // MARK: Services

    public let contentRepository: any ContentRepository
    public let translationService: any TranslationService
    public let bookmarkStore: any BookmarkStore
    public let positionStore: any ReadingPositionStore

    /// Single source of truth for bookmarks. Owns `bookmarkStore` as its
    /// persistence backend; all bookmark reads/writes funnel through here so
    /// every observing view updates live.
    public let bookmarks: BookmarksModel

    // MARK: Reader display settings

    /// Whether per-sentence translations are shown under the original text.
    public var showTranslation: Bool
    /// Active translation language code.
    public var translationLanguage: String
    /// Current reader view mode.
    public var viewMode: ReaderViewMode

    public init(
        contentRepository: any ContentRepository,
        translationService: any TranslationService,
        bookmarkStore: any BookmarkStore,
        positionStore: any ReadingPositionStore,
        showTranslation: Bool = true,
        translationLanguage: String = "ko",
        viewMode: ReaderViewMode = .sentence
    ) {
        self.contentRepository = contentRepository
        self.translationService = translationService
        self.bookmarkStore = bookmarkStore
        self.positionStore = positionStore
        self.bookmarks = BookmarksModel(store: bookmarkStore)
        self.showTranslation = showTranslation
        self.translationLanguage = translationLanguage
        self.viewMode = viewMode
    }

    /// A fully working in-memory environment for previews, tests, and early
    /// integration. Content is empty until the services worker wires real data.
    public static func placeholder() -> AppEnvironment {
        AppEnvironment(
            contentRepository: InMemoryContentRepository(),
            translationService: NoopTranslationService(),
            bookmarkStore: InMemoryBookmarkStore(),
            positionStore: InMemoryReadingPositionStore()
        )
    }
}
