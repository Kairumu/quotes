import SwiftUI

// MARK: - Quotes Design System
//
// Warm paper aesthetic. Amber/bronze brand accent.
// Serif for literary content, SF sans for UI chrome.

// MARK: Color Tokens

enum QuotesColor {
    /// Warm off-white surface (light) / adaptive near-black (dark).
    static let surfacePrimary = Color(light: Color(hex: "#FAF8F5"), dark: Color(hex: "#1A1612"))
    /// Deep warm-brown ink for primary text.
    static let inkPrimary = Color(light: Color(hex: "#2C1810"), dark: Color(hex: "#F2EDE6"))
    /// Muted warm secondary text.
    static let inkSecondary = Color(light: Color(hex: "#7A6055"), dark: Color(hex: "#B0A090"))
    /// Amber-bronze brand accent.
    static let accent = Color(hex: "#C8883A")
    /// Soft warm card fill (lighter than surface, less than tint).
    static let cardFill = Color(light: Color(hex: "#F5F0E8"), dark: Color(hex: "#2A2420"))
    /// 1px subtle stroke for cards.
    static let cardStroke = Color(light: Color(hex: "#E8DDD0"), dark: Color(hex: "#3A3028"))
    /// Accent tint (15%) for icon backgrounds.
    static let accentTint = Color(hex: "#C8883A").opacity(0.15)
    /// Accent tint (8%) for subtle fills.
    static let accentSubtle = Color(hex: "#C8883A").opacity(0.08)
}

// MARK: Spacing Tokens

enum QuotesSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 20
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: Shape Tokens

enum QuotesShape {
    static let cardCorner:  CGFloat = 14
    static let badgeCorner: CGFloat = 6
    static let iconCorner:  CGFloat = 10
}

// MARK: Color Helpers

extension Color {
    /// Create color from hex string (e.g. "#RRGGBB").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let int = UInt64(hex, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Light/dark adaptive color.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - QuotesCard (View Modifier)

struct QuotesCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(QuotesColor.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: QuotesShape.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: QuotesShape.cardCorner)
                    .strokeBorder(QuotesColor.cardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func quotesCard() -> some View {
        modifier(QuotesCardModifier())
    }
}

// MARK: - LanguageBadge

struct LanguageBadge: View {
    let code: String

    var body: some View {
        Text(code.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(QuotesColor.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(QuotesColor.accentTint, in: Capsule())
            .overlay(Capsule().strokeBorder(QuotesColor.accent.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - AccentIconBox

/// Accent-tinted rounded square (Settings.app style).
struct AccentIconBox: View {
    let systemName: String
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: QuotesShape.iconCorner)
                .fill(QuotesColor.accentTint)
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(QuotesColor.accent)
        }
    }
}

// MARK: - CollectionCoverTile

/// Accent-tinted cover tile for collection cards.
struct CollectionCoverTile: View {
    let systemImage: String?
    let title: String
    var size: CGFloat = 60

    private var initial: String {
        title.first.map(String.init) ?? "?"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: QuotesShape.iconCorner + 2)
                .fill(QuotesColor.accentTint)
                .frame(width: size, height: size)
            if let img = systemImage {
                Image(systemName: img)
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(QuotesColor.accent)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.44, weight: .semibold, design: .serif))
                    .foregroundStyle(QuotesColor.accent)
            }
        }
    }
}

// MARK: - BrandedEmptyState

/// Branded empty-state: SF symbol composition in accent tint, serif headline, Korean subcopy.
struct BrandedEmptyState: View {
    let headline: String
    let subtext: String
    var systemImage: String = "book.closed"
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: QuotesSpacing.lg) {
            ZStack {
                Circle()
                    .fill(QuotesColor.accentSubtle)
                    .frame(width: 80, height: 80)
                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(QuotesColor.accent)
            }

            VStack(spacing: QuotesSpacing.sm) {
                Text(headline)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(QuotesColor.inkPrimary)
                    .multilineTextAlignment(.center)

                Text(subtext)
                    .font(.subheadline)
                    .foregroundStyle(QuotesColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(QuotesButtonStyle())
            }
        }
        .padding(QuotesSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - QuotesButtonStyle

struct QuotesButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(QuotesColor.accent)
            .padding(.horizontal, QuotesSpacing.lg)
            .padding(.vertical, QuotesSpacing.sm + 2)
            .background(QuotesColor.accentTint, in: Capsule())
            .overlay(Capsule().strokeBorder(QuotesColor.accent.opacity(0.3), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - BookmarkKind Korean names

extension BookmarkKind {
    var koreanName: String {
        switch self {
        case .highlight:  return "하이라이트"
        case .capture:    return "캡처"
        case .page:       return "페이지"
        case .book:       return "책"
        case .collection: return "컬렉션"
        }
    }

    /// Kind-specific tint color.
    var kindColor: Color {
        switch self {
        case .highlight:  return Color(hex: "#C8883A")   // amber
        case .capture:    return Color(hex: "#7B6FA0")   // muted plum
        case .page:       return Color(hex: "#5A8A6A")   // sage green
        case .book:       return Color(hex: "#C8883A")   // amber (same as accent)
        case .collection: return Color(hex: "#A05050")   // warm red
        }
    }
}
