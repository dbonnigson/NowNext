import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(PurchaseManager.self) private var purchases
    @Environment(Router.self) private var router

    @AppStorage(SettingsKey.nowLimit) private var nowLimit = PlannerLogic.defaultNowLimit
    @AppStorage(SettingsKey.dailyReminderOn) private var reminderOn = false
    @AppStorage(SettingsKey.dailyReminderMinutes) private var reminderMinutes = 8 * 60 + 30
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = true

    @State private var confirmWipe = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    ScreenTitle("Settings")
                    proSection
                    plannerSection
                    reminderSection
                    aboutSection
                    dataSection
                    Callout(symbol: "exclamationmark.shield.fill", title: "Not medical advice", message: LocalizedStringKey(Disclaimer.text))
                        .padding(.top, Theme.spacingS)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, Theme.spacingL)
            }
            .screenBackground()
            .themedTabScreen()
            .confirmationDialog("Delete all tasks and focus history?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    TaskStore.deleteEverything(context: context)
                }
            } message: {
                Text("This can't be undone. Your data only lives on this device.")
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var proSection: some View {
        SectionLabel("NowNext Pro")
        if purchases.isPro {
            settingsRow("checkmark.seal.fill", String(localized: "Pro unlocked"), detail: String(localized: "Thanks for supporting NowNext."), chevron: false)
        } else {
            Button { router.showPaywall = true } label: {
                settingsRow("star.fill", String(localized: "Unlock NowNext Pro"),
                            detail: String(localized: "Insights and time-sense calibration. One-time purchase."),
                            iconColor: Theme.yellow)
            }
            .buttonStyle(.plain)
            Button { Task { await purchases.restore() } } label: {
                settingsRow("arrow.clockwise", String(localized: "Restore Purchases"), detail: nil, chevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var plannerSection: some View {
        SectionLabel("Planner")
        VStack(alignment: .leading, spacing: 12) {
            Text("Max tasks in Now")
                .themeFont(.optionTitle)
                .foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                ForEach(Array(PlannerLogic.nowLimitRange), id: \.self) { n in
                    SelectTile(title: "\(n)", isSelected: PlannerLogic.clampedLimit(nowLimit) == n) {
                        nowLimit = n
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: nowLimit)
            Text("Three is a good start. Fewer things in Now means less overwhelm and more finishing.")
                .themeFont(.detail)
                .foregroundStyle(Theme.muted)
        }
        .padding(Theme.spacingM)
        .themeCard()
    }

    @ViewBuilder
    private var reminderSection: some View {
        SectionLabel("Reminders")
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: reminderBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily “pick your Now”")
                        .themeFont(.optionTitle)
                        .foregroundStyle(Theme.text)
                    Text(notificationsDenied
                         ? String(localized: "Notifications are off for NowNext. Turn them on in the Settings app.")
                         : String(localized: "One gentle nudge a day."))
                        .themeFont(.detail)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.red)
            .frame(minHeight: Theme.optionRowMinHeight)

            if reminderOn {
                Rectangle().fill(Theme.line).frame(height: 1)
                DatePicker(selection: reminderDate, displayedComponents: .hourAndMinute) {
                    Text("Time")
                        .themeFont(.optionTitle)
                        .foregroundStyle(Theme.text)
                }
                .frame(minHeight: 60)
            }
        }
        .padding(.horizontal, Theme.spacingM)
        .themeCard()
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderOn },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await NotificationService.requestAuthorizationIfNeeded()
                        reminderOn = granted
                        notificationsDenied = !granted
                        if granted {
                            NotificationService.scheduleDailyPlanReminder(minutesAfterMidnight: reminderMinutes)
                        }
                    }
                } else {
                    reminderOn = false
                    NotificationService.cancelDailyPlanReminder()
                }
            }
        )
    }

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (c.hour ?? 8) * 60 + (c.minute ?? 30)
                NotificationService.cancelDailyPlanReminder()
                NotificationService.scheduleDailyPlanReminder(minutesAfterMidnight: reminderMinutes)
            }
        )
    }

    @ViewBuilder
    private var aboutSection: some View {
        SectionLabel("About")
        Link(destination: AppLinks.support) {
            settingsRow("questionmark.circle.fill", String(localized: "Help & Support"), detail: nil)
        }
        Link(destination: AppLinks.privacyPolicy) {
            settingsRow("hand.raised.fill", String(localized: "Privacy Policy"), detail: String(localized: "No accounts. No tracking. Data stays on this device."))
        }
        Button { hasOnboarded = false } label: {
            settingsRow("play.rectangle.fill", String(localized: "Show the intro again"), detail: nil)
        }
        .buttonStyle(.plain)
        settingsRow("info.circle.fill", String(localized: "Version"), detail: AppInfo.version, chevron: false)
    }

    @ViewBuilder
    private var dataSection: some View {
        SectionLabel("Your data")
        Button(role: .destructive) {
            confirmWipe = true
        } label: {
            Label("Delete all data", systemImage: "trash")
        }
        .buttonStyle(.secondaryDestructive)
    }

    private func settingsRow(_ symbol: String, _ title: String, detail: String?, chevron: Bool = true, iconColor: Color = Theme.text) -> some View {
        OptionRow(title: title, detail: detail, showsChevron: chevron) {
            IconTile(symbol: symbol, color: iconColor)
        }
        .padding(.horizontal, 14)
        .themeCard()
        .contentShape(Rectangle())
    }
}

enum Disclaimer {
    static let text = String(localized: "NowNext is a planning and focus tool. It is not a medical device and does not diagnose or treat ADHD or any other condition. It's not a substitute for care from a qualified professional.")
}
