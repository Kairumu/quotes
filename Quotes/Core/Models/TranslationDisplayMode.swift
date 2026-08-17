import Foundation

/// How the reader shows original text vs. its translation.
///
/// Replaces the former `showTranslation: Bool`. Persisted globally (see
/// `AppEnvironment`) and rendered consistently across every reader mode, the
/// capture card, and the paginator measurement.
public enum TranslationDisplayMode: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    /// Original text only; translations hidden.
    case originalOnly
    /// Original text with its translation shown alongside (per-sentence).
    case interleave
    /// Translation replaces the original text (falls back to original when a
    /// translation is missing — never blank).
    case translationOnly

    public var id: String { rawValue }

    /// Korean label for pickers/menus.
    public var displayName: String {
        switch self {
        case .originalOnly: return "원문만"
        case .interleave: return "병기"
        case .translationOnly: return "번역만"
        }
    }
}
