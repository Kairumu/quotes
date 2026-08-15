import SwiftUI

// MARK: - BookPalette
//
// Per-book procedural palette. Kakao's "living illustrated thumbnails" become
// "living typographic covers" — every book gets a stable, warm, light/dark
// adaptive palette WITHOUT any data/schema change.
//
// The token is DERIVED deterministically from the stable `bookId` via FNV-1a,
// mirroring the token-string pattern of `HighlightPalette` (a book's palette is
// never stored; it is recomputed identically on every launch/device). A future
// optional `Book.paletteToken` field can be honored additively — see
// `token(for book:)` — without breaking the sample JSON or Firestore.
//
// GUARDRAIL: the palette tints BACKGROUNDS only. Text always uses the
// guaranteed-contrast ink colors (`heroInk`/`heroInkSecondary`, which resolve to
// the warm `QuotesColor` inks), so legibility holds on every tint in light & dark.

enum BookPalette {

    /// Curated set of warm, adaptive palette tokens (8), in display order.
    enum Token: String, CaseIterable, Identifiable {
        case terracotta
        case olive
        case plum
        case denim
        case ochre
        case teal
        case rose
        case slate

        var id: String { rawValue }

        /// (light-start, light-end, dark-start, dark-end) hex stops.
        /// Light stops are low-saturation warm pastels; dark stops are
        /// warm-black-shifted (never pure black), preserving the warm-paper
        /// language in both appearances.
        private var stops: (String, String, String, String) {
            switch self {
            case .terracotta: return ("#ECD6C8", "#E1BFA9", "#342620", "#241A15")
            case .olive:      return ("#DDDEC4", "#CACBA6", "#2C2E20", "#1F2016")
            case .plum:       return ("#E0CFDD", "#CDB4C7", "#302636", "#221926")
            case .denim:      return ("#CBD6E0", "#AFC1D4", "#212B34", "#171F27")
            case .ochre:      return ("#ECDCBC", "#E0C994", "#342C1C", "#241E12")
            case .teal:       return ("#C6DED7", "#A6C8BE", "#1E2E2A", "#14201D")
            case .rose:       return ("#ECCED4", "#E0AEB8", "#342026", "#24161A")
            case .slate:      return ("#D2D4D8", "#B8BCC4", "#26282C", "#1A1C20")
            }
        }

        /// Light/dark-adaptive diagonal tint gradient (background only).
        var backgroundGradient: LinearGradient {
            let (ls, le, ds, de) = stops
            return LinearGradient(
                colors: [
                    Color(light: Color(hex: ls), dark: Color(hex: ds)),
                    Color(light: Color(hex: le), dark: Color(hex: de))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Primary ink — guaranteed to contrast on the tint (warm-paper ink).
        var heroInk: Color { QuotesColor.inkPrimary }

        /// Secondary ink — guaranteed to contrast on the tint (warm-paper ink).
        var heroInkSecondary: Color { QuotesColor.inkSecondary }
    }

    /// FNV-1a (32-bit) over the UTF-8 bytes of `string`.
    ///
    /// Deterministic across launches/devices (unlike `Hashable.hashValue`, which
    /// is per-process salted). FNV-1a scrambles adjacent ids to well-distributed
    /// tokens, avoiding the sequential clustering a byte-sum would produce
    /// (`b001/b002/b003`).
    static func fnv1a(_ string: String) -> UInt32 {
        var hash: UInt32 = 0x811c_9dc5          // FNV offset basis
        for byte in string.utf8 {
            hash = (hash ^ UInt32(byte)) &* 0x0100_0193   // XOR then FNV prime (wrapping)
        }
        return hash
    }

    /// Stable palette token for a `bookId` (id-hash resolver).
    static func token(for bookId: String) -> Token {
        let all = Token.allCases
        let index = Int(fnv1a(bookId) % UInt32(all.count))
        return all[index]
    }

    /// Palette token for a `Book`.
    ///
    /// Forward-compat stub: v1 delegates to the id-hash. When an optional
    /// `Book.paletteToken: String?` is later added, prefer it here
    /// (`Token(rawValue:) ?? token(for: book.id)`) — additive, non-breaking.
    static func token(for book: Book) -> Token {
        token(for: book.id)
    }
}
