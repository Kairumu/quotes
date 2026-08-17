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

    // MARK: Reader display settings (persisted in UserDefaults)
    //
    // `@AppStorage` does not compose with `@Observable`, so these three settings
    // are backed by UserDefaults manually: seeded from persistence in `init`
    // and written through on every mutation via `didSet`. The `reader.viewMode`
    // key is THE single source of truth for the reader mode.

    /// How translations are shown (원문만/병기/번역만).
    public var translationDisplay: TranslationDisplayMode {
        didSet { Self.defaults.set(translationDisplay.rawValue, forKey: Self.displayKey) }
    }
    /// Active translation language code.
    public var translationLanguage: String {
        didSet { Self.defaults.set(translationLanguage, forKey: Self.languageKey) }
    }
    /// Current reader view mode.
    public var viewMode: ReaderViewMode {
        didSet { Self.defaults.set(viewMode.rawValue, forKey: Self.viewModeKey) }
    }

    // MARK: Persistence keys

    @ObservationIgnored private static let defaults = UserDefaults.standard
    @ObservationIgnored static let displayKey = "reader.translationDisplay"
    @ObservationIgnored static let languageKey = "reader.translationLanguage"
    @ObservationIgnored static let viewModeKey = "reader.viewMode"

    // MARK: Language options

    /// The full v1 language set, in menu order.
    public static let allLanguageCodes = ["ko", "zh", "ja", "en"]

    /// Language codes offered for a book: the full static set minus the book's
    /// original language.
    ///
    /// v1-sample-only simplification: the list is static. Future non-sample
    /// books must filter via `TranslationService.availableLanguages(bookId:)`
    /// instead of assuming ko/zh/ja/en.
    public static func languageOptions(for book: Book) -> [String] {
        allLanguageCodes.filter { $0 != book.originalLanguage }
    }

    /// The persisted language clamped to a language the book can actually show:
    /// if the stored global language equals the book's original language (never a
    /// translation), fall back to `"ko"` for display without mutating the stored
    /// global setting.
    public func effectiveLanguage(for book: Book) -> String {
        translationLanguage == book.originalLanguage ? "ko" : translationLanguage
    }

    /// Human-readable name for a language code.
    public static func languageDisplayName(_ code: String) -> String {
        switch code {
        case "ko": return "한국어"
        case "zh": return "中文"
        case "ja": return "日本語"
        case "en": return "English"
        default: return code
        }
    }

    public init(
        contentRepository: any ContentRepository,
        translationService: any TranslationService,
        bookmarkStore: any BookmarkStore,
        positionStore: any ReadingPositionStore,
        translationDisplay: TranslationDisplayMode? = nil,
        translationLanguage: String? = nil,
        viewMode: ReaderViewMode? = nil
    ) {
        self.contentRepository = contentRepository
        self.translationService = translationService
        self.bookmarkStore = bookmarkStore
        self.positionStore = positionStore
        self.bookmarks = BookmarksModel(store: bookmarkStore)

        // Seed from persistence (explicit argument wins, else stored value, else
        // fresh default). No migration needed: `showTranslation` was never
        // persisted, so a first launch simply lands on `.interleave`.
        let defaults = Self.defaults
        self.translationDisplay = translationDisplay
            ?? defaults.string(forKey: Self.displayKey).flatMap(TranslationDisplayMode.init(rawValue:))
            ?? .interleave
        self.translationLanguage = translationLanguage
            ?? defaults.string(forKey: Self.languageKey)
            ?? "ko"
        // Fresh installs / missing key default to 이어보기 (closest to the retired
        // vertical sentence-list feel). Existing installs keep their saved mode.
        self.viewMode = viewMode
            ?? defaults.string(forKey: Self.viewModeKey).flatMap(ReaderViewMode.init(rawValue:))
            ?? .continuous
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
