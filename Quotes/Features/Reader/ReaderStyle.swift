import SwiftUI
import UIKit

/// Shared visual constants for the reading experience.
///
/// Reading-focused: a serif face for original text, a quieter sans face for
/// translations, generous line spacing, and a warm, paper-like surface. All
/// layout metrics live here so the on-screen views and the offscreen
/// `Paginator` measure identical geometry (pages must not overflow).
enum ReaderStyle {
    // MARK: Fonts (SwiftUI)

    /// Serif font for original passage text.
    static let originalFont: Font = .system(.body, design: .serif)
    /// Serif font for original text on capture cards (slightly larger).
    static let cardOriginalFont: Font = .system(.title3, design: .serif)
    /// Sans font for translated text.
    static let translationFont: Font = .callout

    // MARK: Line spacing

    static let lineSpacing: CGFloat = 7
    static let paragraphLineSpacing: CGFloat = 8

    // MARK: Row metrics (shared by SentenceRowView and Paginator)

    /// Vertical padding above/below a sentence row.
    static let rowVerticalPadding: CGFloat = 10
    /// Horizontal padding on each side of a sentence row.
    static let rowHorizontalPadding: CGFloat = 20
    /// Spacing between the original text and its translation inside a row.
    static let rowInternalSpacing: CGFloat = 6
    /// Spacing between sibling rows in a vertical stack.
    static let rowSpacing: CGFloat = 4
    /// Leading inset applied to a translation block (accent rule + gap).
    static let translationLeadingInset: CGFloat = 12
    /// Width of the thin accent rule shown before a translation.
    static let translationRuleWidth: CGFloat = 2

    /// Padding above a chunk title header.
    static let titleTopPadding: CGFloat = 24
    /// Padding below a chunk title header.
    static let titleBottomPadding: CGFloat = 8

    // MARK: Tints

    /// Opacity applied to a resolved highlight color when used as a row tint.
    static let highlightTintOpacity: Double = 0.34
    /// Accent-blue tint applied to the active selection (distinct from highlight).
    static let selectionTint = Color.accentColor.opacity(0.24)
    /// Accent rule colour before a translation.
    static let translationRuleColor = Color.accentColor.opacity(0.35)

    /// Background tint for a sentence given its resolved highlight color and
    /// selection state. `highlightColor` is the per-highlight palette color
    /// (already resolved via `HighlightPalette.color(forTag:)`, `nil` when the
    /// sentence is not highlighted); it is rendered at `highlightTintOpacity`.
    static func tint(highlightColor: Color?, selected: Bool) -> Color {
        if selected { return selectionTint }
        if let highlightColor { return highlightColor.opacity(highlightTintOpacity) }
        return .clear
    }

    // MARK: Reading surface

    /// Warm, paper-like reading background. Dark-mode aware and semantic.
    static let readingBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            // Warm near-black, a touch warmer than pure systemBackground.
            return UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1.0)
        } else {
            // Soft cream paper.
            return UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)
        }
    })

    /// Coordinate space name used for drag-to-select frame tracking.
    static let selectionSpace = "reader.selection.space"
}
