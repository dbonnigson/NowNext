import SwiftData
import SwiftUI

// MARK: - Buttons

/// Red fill, 2pt white inner border, white caps, 54pt tall.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .themeFont(.button)
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                    .fill(isEnabled ? Theme.red : Theme.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                    .strokeBorder(isEnabled ? Theme.text : Theme.line, lineWidth: Theme.borderSelected)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : (isEnabled ? 1 : 0.6))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// surfaceRaised fill, white semibold, 54pt tall.
struct SecondaryButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .themeFont(.bodyStrong)
            .foregroundStyle(destructive ? Theme.red : Theme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                    .fill(Theme.surfaceRaised)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondaryDestructive: SecondaryButtonStyle { SecondaryButtonStyle(destructive: true) }
}

/// Pinned bottom action area: background color with a 1pt surfaceRaised divider on top.
/// Two actions: secondary on the left, primary on the right with higher layout priority.
struct BottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.surfaceRaised)
                .frame(height: 1)
            HStack(spacing: 12) {
                content
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Theme.background)
    }
}

// MARK: - Cards & surfaces

struct CardBackground: ViewModifier {
    var selected = false
    var radius: CGFloat = Theme.radiusCard

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(selected ? Theme.red : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(selected ? Theme.text : Theme.line,
                                  lineWidth: selected ? Theme.borderSelected : Theme.borderThin)
            )
    }
}

extension View {
    /// Surface card with a 1pt line border (or red + 2pt white border when selected).
    func themeCard(selected: Bool = false, radius: CGFloat = Theme.radiusCard) -> some View {
        modifier(CardBackground(selected: selected, radius: radius))
    }

    /// Near-black screen background everywhere.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    /// Black, always-visible navigation bar with white controls.
    func themedNavigationBar() -> some View {
        self
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Makes a List row look like a theme card, inset by the screen gutter.
    func themedListRow(selected: Bool = false) -> some View {
        self
            .listRowInsets(EdgeInsets(top: 4, leading: Theme.gutter + 8, bottom: 4, trailing: Theme.gutter + 12))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(selected ? Theme.red : Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                            .strokeBorder(selected ? Theme.text : Theme.line,
                                          lineWidth: selected ? Theme.borderSelected : Theme.borderThin)
                    )
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 2)
            )
    }

    /// A List row with no card (for headers, hints and banners inside lists).
    func plainListRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 4, leading: Theme.gutter, bottom: 4, trailing: Theme.gutter))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// Standard list chrome for themed screens.
    func themedList() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
            .screenBackground()
    }
}

// MARK: - Text blocks

/// "WHY THIS WORKS" style label: 12pt bold caps, tracking 1.2, muted.
struct SectionLabel: View {
    let text: LocalizedStringKey
    var trailing: String?

    init(_ text: LocalizedStringKey, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
            if let trailing {
                Text(verbatim: "· \(trailing)")
                    .monospacedDigit()
            }
        }
        .themeFont(.sectionLabel)
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.spacingS)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Page title: 30pt heavy caps.
struct ScreenTitle: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .themeFont(.screenTitle)
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Glyphs

/// 44pt rounded-square icon tile.
struct IconTile: View {
    let symbol: String
    var color: Color = Theme.text

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(color)
            .frame(width: Theme.iconTile, height: Theme.iconTile)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusIconTile, style: .continuous)
                    .fill(Theme.surfaceRaised)
            )
            .accessibilityHidden(true)
    }
}

/// Circular "plate" check button, 44pt. Done = red plate, white border, white check.
struct PlateCheck: View {
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isDone ? Theme.red : Theme.surfaceRaised)
                Circle()
                    .strokeBorder(isDone ? Theme.text : Theme.line,
                                  lineWidth: isDone ? Theme.borderSelected : Theme.borderThin)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.text)
                        .transition(.scale)
                }
            }
            .frame(width: Theme.minTap, height: Theme.minTap)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? Text("Mark not done") : Text("Mark done"))
    }
}

/// Capsule showing a choice already made.
struct Chip: View {
    let text: String
    var symbol: String?
    var symbolColor: Color = Theme.text

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(symbolColor)
                    .accessibilityHidden(true)
            }
            Text(text)
                .monospacedDigit()
        }
        .themeFont(.chip)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: Theme.borderThin))
    }
}

/// Yellow "PRO" lock tag.
struct LockTag: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
            Text("Pro")
        }
        .font(.system(size: 12, weight: .heavy))
        .textCase(.uppercase)
        .foregroundStyle(Theme.yellow)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.warningFill))
        .overlay(Capsule().strokeBorder(Theme.yellow, lineWidth: Theme.borderThin))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pro feature")
    }
}

// MARK: - Option row

/// Min 72pt row: leading glyph, title + detail, trailing chevron.
struct OptionRow<Leading: View>: View {
    let title: String
    var detail: String?
    var showsChevron = true
    var struck = false
    @ViewBuilder let leading: Leading

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .themeFont(.optionTitle)
                    .foregroundStyle(struck ? Theme.muted : Theme.text)
                    .strikethrough(struck, color: Theme.muted)
                    .lineLimit(3)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .themeFont(.detail)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: Theme.optionRowMinHeight)
    }
}

/// A task as an option row. Tapping the text opens the detail sheet.
struct TaskRow: View {
    let task: TaskItem
    var showSlot = false
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PlateCheck(isDone: task.isDone, action: onToggle)
            Button(action: onOpen) {
                OptionRow(title: task.title, detail: detailText, struck: task.isDone) {
                    EmptyView()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens task details")
        }
    }

    private var detailText: String {
        var parts: [String] = []
        if showSlot { parts.append(task.slot.title) }
        if let steps = task.stepProgressText { parts.append(steps) }
        if let est = task.estimateMinutes {
            parts.append(String(localized: "Guess \(DurationText.short(minutes: est))"))
        }
        if task.trackedSeconds >= 60 {
            parts.append(String(localized: "Focused \(DurationText.short(seconds: task.trackedSeconds))"))
        }
        return parts.joined(separator: " · ")
    }
}

/// Selectable tile used for pickers (slot, durations, estimates).
struct SelectTile: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.text : Theme.muted)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(size: Theme.TextStyle.bodyStrong.scaledSize(), weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 4)
            .themeCard(selected: isSelected, radius: Theme.radiusButton)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Stats, progress, callouts

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .themeFont(.statNumber)
                .foregroundStyle(Theme.red)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .themeFont(.statLabel)
                .foregroundStyle(Theme.muted)
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
        .accessibilityElement(children: .combine)
    }
}

/// "Loading" rail of small vertical bars. Filled = red & tall, empty = raised & short, gray end caps.
struct ProgressRail: View {
    let filled: Int
    let total: Int
    var label: String?

    var body: some View {
        HStack(spacing: 10) {
            HStack(alignment: .center, spacing: 3) {
                cap
                ForEach(0..<max(total, 1), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(i < filled ? Theme.red : Theme.surfaceRaised)
                        .frame(width: 5, height: i < filled ? 22 : 14)
                }
                cap
            }
            .animation(.easeOut(duration: 0.2), value: filled)
            if let label {
                Text(label)
                    .themeFont(.railLabel)
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? String(localized: "\(filled) of \(total)"))
    }

    private var cap: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Theme.gray)
            .frame(width: 3, height: 22)
    }
}

/// Safety / important callout: yellow lock icon, warningFill, 1pt yellow border.
struct Callout: View {
    var symbol = "lock.fill"
    let title: LocalizedStringKey?
    let message: LocalizedStringKey

    init(symbol: String = "lock.fill", title: LocalizedStringKey? = nil, message: LocalizedStringKey) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.yellow)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .themeFont(.sectionLabel)
                        .foregroundStyle(Theme.yellow)
                }
                Text(message)
                    .themeFont(.detail)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.radiusCallout, style: .continuous).fill(Theme.warningFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCallout, style: .continuous).strokeBorder(Theme.yellow, lineWidth: Theme.borderThin))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sheets

/// Header for bottom sheets: caps title + 44pt round close button top-right.
struct SheetHeader: View {
    let title: LocalizedStringKey
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .themeFont(.cardTitle)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.text)
                    .frame(width: Theme.minTap, height: Theme.minTap)
                    .background(Circle().fill(Theme.surfaceRaised))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

extension View {
    /// Standard bottom-sheet chrome: medium/large detents, drag indicator, surface background, 28pt corners.
    func themedSheet() -> some View {
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.surface)
            .presentationCornerRadius(Theme.radiusSheet)
            .preferredColorScheme(.dark)
    }
}

// MARK: - Alerts

/// Shared "Now is full" alert.
struct NowFullAlert: ViewModifier {
    @Binding var limit: Int?

    func body(content: Content) -> some View {
        content.alert(
            "Now is full",
            isPresented: Binding(get: { limit != nil }, set: { if !$0 { limit = nil } }),
            presenting: limit
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { limit in
            Text("You've got \(limit) things in Now. Finish one or move one back to Next first.")
        }
    }
}

extension View {
    func nowFullAlert(_ limit: Binding<Int?>) -> some View {
        modifier(NowFullAlert(limit: limit))
    }
}

/// Estimate choices used in pickers.
enum EstimateOptions {
    static let minutes: [Int] = [5, 10, 15, 20, 30, 45, 60, 90, 120]
}

/// Menu of "Move to …" buttons, excluding the task's current slot.
struct MoveMenuItems: View {
    let task: TaskItem
    let move: (Slot) -> Void

    var body: some View {
        ForEach(Slot.allCases.filter { $0 != task.slot }) { slot in
            Button {
                move(slot)
            } label: {
                Label(String(localized: "Move to \(slot.title)"), systemImage: slot.symbol)
            }
        }
    }
}
