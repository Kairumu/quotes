import SwiftUI

// MARK: - HighlightPalette
//
// Fixed v1 highlight color palette (5 warm tokens).
//
// A bookmark's `colorTag` stores a **stable token-name string**
// (`amber|coral|sage|sky|lavender`), never a hex value. This decouples the
// rendered color from the persisted value: hues can be retuned or made more
// light/dark-adaptive without a migration, and the token is safe to sync
// verbatim to Firestore (`users/{uid}/bookmarks.colorTag`).
//
// `nil`/unknown tags resolve to `amber` (the current default highlight tint),
// so all existing bookmarks render unchanged — zero migration.

enum HighlightPalette {

    /// The five palette tokens, in display order. `amber` is the default.
    enum Token: String, CaseIterable, Identifiable {
        case amber
        case coral
        case sage
        case sky
        case lavender

        var id: String { rawValue }

        /// Light/dark-adaptive tint color. Hues are user-tweakable; dark
        /// variants can diverge from light here later without touching stored
        /// data (the `colorTag` token name is stable).
        var color: Color {
            switch self {
            case .amber:    return Color(light: Color(hex: "#C8883A"), dark: Color(hex: "#C8883A"))
            case .coral:    return Color(light: Color(hex: "#D9765B"), dark: Color(hex: "#D9765B"))
            case .sage:     return Color(light: Color(hex: "#5A8A6A"), dark: Color(hex: "#5A8A6A"))
            case .sky:      return Color(light: Color(hex: "#5B84A6"), dark: Color(hex: "#5B84A6"))
            case .lavender: return Color(light: Color(hex: "#8C7AA6"), dark: Color(hex: "#8C7AA6"))
            }
        }
    }

    /// The default token, used when a bookmark has no color tag.
    static let defaultToken: Token = .amber

    /// Resolve a stored `colorTag` string to a `Token`; `nil`/unknown → amber.
    static func token(forTag tag: String?) -> Token {
        guard let tag, let token = Token(rawValue: tag) else { return defaultToken }
        return token
    }

    /// Resolve a stored `colorTag` string to a `Color`; `nil`/unknown → amber.
    static func color(forTag tag: String?) -> Color {
        token(forTag: tag).color
    }
}
