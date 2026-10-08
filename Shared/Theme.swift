import SwiftUI
import UIKit

/// Single source of truth for the "in Progress" visual style
/// (black, signal red, white outlines, yellow for highlights only).
/// Compiled into the app AND the widget extension.
enum Theme {
    // MARK: Colors

    static let background = Color(hex: 0x050505)
    static let surface = Color(hex: 0x141414)
    static let surfaceRaised = Color(hex: 0x1F1F1F)
    static let line = Color(hex: 0x333333)
    static let text = Color(hex: 0xFFFFFF)
    static let muted = Color(hex: 0xC7C7C7)
    static let red = Color(hex: 0xE3120B)
    static let yellow = Color(hex: 0xF6C21C)
    static let gray = Color(hex: 0x9A9A9A)
    static let warningFill = Color(hex: 0x2A2413)

    // MARK: Spacing

    static let gutter: CGFloat = 20
    static let spacingS: CGFloat = 10
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24

    // MARK: Radii

    static let radiusCard: CGFloat = 16
    static let radiusButton: CGFloat = 14
    static let radiusHero: CGFloat = 18
    static let radiusIconTile: CGFloat = 12
    static let radiusSheet: CGFloat = 28
    static let radiusCallout: CGFloat = 14

    // MARK: Sizes

    static let minTap: CGFloat = 44
    static let buttonHeight: CGFloat = 54
    static let optionRowMinHeight: CGFloat = 72
    static let iconTile: CGFloat = 44
    static let borderThin: CGFloat = 1
    static let borderSelected: CGFloat = 2

    // MARK: Typography

    /// Every text style in the app. Sizes are base sizes at the default
    /// Dynamic Type setting; they scale with `UIFontMetrics`.
    enum TextStyle {
        case wordmark        // 58 black, red
        case heroTitle       // 44 black
        case screenTitle     // 30 heavy, caps
        case cardTitle       // 19 heavy, caps
        case optionTitle     // 17 semibold
        case body            // 16 regular
        case bodyStrong      // 16 semibold
        case detail          // 14 regular (muted)
        case sectionLabel    // 12 bold, caps, tracking 1.2
        case railLabel       // 12 semibold, caps
        case button          // 16 heavy, caps, tracking 1
        case chip            // 12.5 semibold
        case statNumber      // 26 black, monospaced digits
        case statLabel       // 12 medium
        case timer           // 64 black, monospaced digits
        case lockup          // 18 bold (the "★ in Progress ★" line)

        var size: CGFloat {
            switch self {
            case .wordmark: 58
            case .heroTitle: 44
            case .screenTitle: 30
            case .cardTitle: 19
            case .optionTitle: 17
            case .body, .bodyStrong, .button: 16
            case .detail: 14
            case .sectionLabel, .railLabel, .statLabel: 12
            case .chip: 12.5
            case .statNumber: 26
            case .timer: 64
            case .lockup: 18
            }
        }

        var weight: Font.Weight {
            switch self {
            case .wordmark, .heroTitle, .statNumber, .timer: .black
            case .screenTitle, .cardTitle, .button: .heavy
            case .optionTitle, .bodyStrong, .railLabel, .chip: .semibold
            case .sectionLabel, .lockup: .bold
            case .statLabel: .medium
            case .body, .detail: .regular
            }
        }

        /// The Dynamic Type curve each style follows.
        var textStyle: UIFont.TextStyle {
            switch self {
            case .wordmark, .heroTitle, .timer: .largeTitle
            case .screenTitle: .title1
            case .statNumber: .title2
            case .cardTitle, .lockup: .title3
            case .optionTitle, .body, .bodyStrong: .body
            case .button: .headline
            case .detail: .subheadline
            case .sectionLabel, .railLabel, .chip, .statLabel: .caption1
            }
        }

        var isUppercased: Bool {
            switch self {
            case .wordmark, .heroTitle, .screenTitle, .cardTitle, .sectionLabel, .railLabel, .button: true
            default: false
            }
        }

        var tracking: CGFloat {
            switch self {
            case .sectionLabel: 1.2
            case .button: 1
            case .railLabel: 0.8
            default: 0
            }
        }

        var monospacedDigits: Bool {
            self == .statNumber || self == .timer
        }

        /// Point size after Dynamic Type scaling for the given content size.
        func scaledSize(for category: UIContentSizeCategory? = nil) -> CGFloat {
            let metrics = UIFontMetrics(forTextStyle: textStyle)
            if let category {
                let traits = UITraitCollection(preferredContentSizeCategory: category)
                return metrics.scaledValue(for: size, compatibleWith: traits)
            }
            return metrics.scaledValue(for: size)
        }
    }
}

// MARK: - Font extensions

extension Font {
    /// Scaled system font for a theme style (uses the current Dynamic Type setting).
    static func theme(_ style: Theme.TextStyle) -> Font {
        .system(size: style.scaledSize(), weight: style.weight)
    }

    static var themeWordmark: Font { .theme(.wordmark) }
    static var themeHero: Font { .theme(.heroTitle) }
    static var themeScreenTitle: Font { .theme(.screenTitle) }
    static var themeCardTitle: Font { .theme(.cardTitle) }
    static var themeOptionTitle: Font { .theme(.optionTitle) }
    static var themeBody: Font { .theme(.body) }
    static var themeDetail: Font { .theme(.detail) }
    static var themeSectionLabel: Font { .theme(.sectionLabel) }
    static var themeButton: Font { .theme(.button) }
}

/// Applies a theme text style: scaled font, caps, tracking and monospaced digits.
/// Reads `dynamicTypeSize` so text re-scales live when the user changes it.
struct ThemeTextModifier: ViewModifier {
    let style: Theme.TextStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        let size = style.scaledSize(for: UIContentSizeCategory(dynamicTypeSize))
        let base = content
            .font(.system(size: size, weight: style.weight))
            .tracking(style.tracking)
            .textCase(style.isUppercased ? .uppercase : nil)
        if style.monospacedDigits {
            base.monospacedDigit()
        } else {
            base
        }
    }
}

extension View {
    func themeFont(_ style: Theme.TextStyle) -> some View {
        modifier(ThemeTextModifier(style: style))
    }
}

// MARK: - Hex colors

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
