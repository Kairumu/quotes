import Foundation

/// How the reader renders content.
///
/// Persisted as the global `reader.viewMode` UserDefaults key (the single source
/// of truth for the reader mode). Raw values are stable and must never change:
/// old SwiftData `ReadingPositionRecord.viewModeRaw` values (`"sentence"`,
/// `"paragraph"`, `"page"`) still decode into the same cases.
public enum ReaderViewMode: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    /// One sentence per screen, horizontal swipe (carousel).
    case sentence
    /// One paragraph per screen, horizontal swipe (carousel).
    case paragraph
    /// Dynamically paginated layout (page numbers derived from sentence anchors).
    case page
    /// Continuous vertical scroll in paragraph-flow style (이어보기).
    case continuous

    public var id: String { rawValue }

    /// Human-readable label for pickers. Korean labels live here so the mode
    /// picker and the UI tests share a single source of truth.
    public var displayName: String {
        switch self {
        case .sentence: return "문장"
        case .paragraph: return "문단"
        case .page: return "페이지"
        case .continuous: return "이어보기"
        }
    }

    /// Whether this mode is a paged (horizontal, one-unit-per-screen) mode.
    /// `.sentence`/`.paragraph`/`.page` are paged; `.continuous` is not. Used to
    /// gate reading-position derivation (paged modes anchor to the page's first
    /// sentence; continuous uses the topmost visible sentence).
    public var isPaged: Bool { self != .continuous }

    /// Whether this mode is usable in the current release.
    public var isAvailable: Bool {
        true
    }
}
