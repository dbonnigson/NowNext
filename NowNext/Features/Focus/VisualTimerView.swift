import SwiftUI

/// A shrinking colored disk that shows time as *space*, not just numbers —
/// easier to read at a glance when time feels slippery.
struct VisualTimerView: View {
    /// 1 = full time left, 0 = done.
    let fractionRemaining: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
            PieSlice(fraction: fractionRemaining)
                .fill(color)
            Circle()
                .strokeBorder(Theme.text, lineWidth: Theme.borderSelected)
            Circle()
                .fill(Theme.background)
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(Theme.text, lineWidth: Theme.borderSelected))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Wedge starting at 12 o'clock, sweeping clockwise for `fraction` of the circle.
struct PieSlice: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let f = min(max(fraction, 0), 1)
        var path = Path()
        guard f > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + 360 * f)
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    VisualTimerView(fractionRemaining: 0.66, color: Theme.red)
        .padding(40)
        .screenBackground()
}
