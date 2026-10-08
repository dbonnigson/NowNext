import UIKit
import SwiftUI

/// Heater-style shield outline used by the badge logo.
struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x + 0.5 * w, y: y))
        p.addQuadCurve(to: CGPoint(x: x + w, y: y + 0.14 * h),
                       control: CGPoint(x: x + 0.78 * w, y: y + 0.11 * h))
        p.addLine(to: CGPoint(x: x + w, y: y + 0.50 * h))
        p.addQuadCurve(to: CGPoint(x: x + 0.5 * w, y: y + h),
                       control: CGPoint(x: x + 0.97 * w, y: y + 0.84 * h))
        p.addQuadCurve(to: CGPoint(x: x, y: y + 0.50 * h),
                       control: CGPoint(x: x + 0.03 * w, y: y + 0.84 * h))
        p.addLine(to: CGPoint(x: x, y: y + 0.14 * h))
        p.addQuadCurve(to: CGPoint(x: x + 0.5 * w, y: y),
                       control: CGPoint(x: x + 0.22 * w, y: y + 0.11 * h))
        p.closeSubpath()
        return p
    }
}

/// Shield badge: black shield, thick white outline, inner red outline,
/// the Now/Next/Later bars symbol, and a yellow lightning bolt with a black stroke.
struct ShieldBadge: View {
    var size: CGFloat = 120

    var body: some View {
        let w = size
        let h = size * 1.15
        ZStack {
            ShieldShape().fill(Theme.text)
            ShieldShape().fill(Theme.background)
                .padding(w * 0.06)
            ShieldShape().stroke(Theme.red, lineWidth: w * 0.03)
                .padding(w * 0.13)

            // Symbol: three stacked bars (Now in red, Next and Later in white).
            VStack(alignment: .leading, spacing: w * 0.06) {
                Capsule().fill(Theme.red).frame(width: w * 0.46, height: w * 0.1)
                Capsule().fill(Theme.text).frame(width: w * 0.34, height: w * 0.1)
                Capsule().fill(Theme.text).frame(width: w * 0.22, height: w * 0.1)
            }
            .frame(width: w * 0.46, alignment: .leading)
            .offset(y: -h * 0.04)

            // Lightning bolt, yellow with a black outline.
            Image(systemName: "bolt.fill")
                .font(.system(size: w * 0.3, weight: .black))
                .foregroundStyle(Theme.yellow)
                .shadow(color: .black, radius: 0, x: 1.5, y: 0)
                .shadow(color: .black, radius: 0, x: -1.5, y: 0)
                .shadow(color: .black, radius: 0, x: 0, y: 1.5)
                .shadow(color: .black, radius: 0, x: 0, y: -1.5)
                .offset(x: w * 0.22, y: h * 0.2)
        }
        .frame(width: w, height: h)
        .accessibilityHidden(true)
    }
}

/// Wordmark lockup: the big red word, then "★ in Progress ★".
/// "NOW ⚡ NEXT": all caps with a yellow bolt between the words, so it reads
/// as two words. The bolt is an SF Symbol (yellow = highlight only).
struct NowNextName: View {
    var style: Theme.TextStyle = .wordmark

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let size = style.scaledSize(for: UIContentSizeCategory(dynamicTypeSize))
        let bolt = Text(Image(systemName: "bolt.fill"))
            .font(.system(size: size * 0.4, weight: style.weight))
            .foregroundStyle(Theme.yellow)
            .baselineOffset(size * 0.34) // lifts the small bolt into the upper half of the capitals
        Text("\(Text(verbatim: "NOW"))\(Text(verbatim: "\u{2009}"))\(bolt)\(Text(verbatim: "\u{2009}"))\(Text(verbatim: "NEXT"))")
            .font(.system(size: size, weight: style.weight))
            .accessibilityLabel("NowNext")
    }
}

struct Wordmark: View {
    var tagline: LocalizedStringKey = "in Progress"
    var compact = false

    var body: some View {
        VStack(spacing: 2) {
            NowNextName(style: compact ? .heroTitle : .wordmark)
                .foregroundStyle(Theme.red)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.yellow)
                Text(tagline)
                    .themeFont(.lockup)
                    .foregroundStyle(Theme.text)
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.yellow)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NowNext, in Progress")
        .accessibilityAddTraits(.isHeader)
    }
}

/// Badge centered above the wordmark (home screen / onboarding).
struct BrandLockup: View {
    var badgeSize: CGFloat = 96
    var compact = false

    var body: some View {
        VStack(spacing: 12) {
            ShieldBadge(size: badgeSize)
            Wordmark(compact: compact)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BrandLockup()
        .padding()
        .screenBackground()
}
