import Foundation

/// How the reader renders content.
public enum ReaderViewMode: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    /// One sentence at a time.
    case sentence
    /// One paragraph at a time.
    case paragraph
    /// Dynamically paginated layout (page numbers derived from sentence anchors).
    case page

    public var id: String { rawValue }

    /// Human-readable label for pickers.
    public var displayName: String {
        switch self {
        case .sentence: return "Sentence"
        case .paragraph: return "Paragraph"
        case .page: return "Page"
        }
    }

    /// Whether this mode is usable in the current release.
    public var isAvailable: Bool {
        true
    }
}
