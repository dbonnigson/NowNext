import Charts
import SwiftData
import SwiftUI

/// Pro: focus history and personal time-estimate calibration.
struct InsightsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(Router.self) private var router

    @Query(sort: \FocusSession.endedAt, order: .reverse)
    private var sessions: [FocusSession]

    @Query(filter: #Predicate<TaskItem> { $0.completedAt != nil })
    private var finishedTasks: [TaskItem]

    @Query private var allTasks: [TaskItem]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    ScreenTitle("Insights")
                    if purchases.isPro {
                        content
                    } else {
                        locked
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, Theme.spacingL)
            }
            .screenBackground()
            .themedTabScreen()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !purchases.isPro {
                    BottomActionBar {
                        Button("Unlock Pro") { router.showPaywall = true }
                            .buttonStyle(.primary)
                    }
                }
            }
        }
    }

    // MARK: Data

    private var week: [FocusHistory.Day] {
        FocusHistory.lastDays(7, entries: sessions.map { .init(endedAt: $0.endedAt, focusedSeconds: $0.focusedSeconds) })
    }

    private var weekMinutes: Int { week.reduce(0) { $0 + $1.minutes } }

    private var doneThisWeek: Int {
        guard let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) else { return 0 }
        return finishedTasks.filter { ($0.completedAt ?? .distantPast) >= start }.count
    }

    private var stats: EstimateStats {
        EstimateStats(samples: allTasks.compactMap { t in
            guard let est = t.estimateMinutes else { return nil }
            return .init(estimateMinutes: est, trackedSeconds: t.trackedSeconds)
        })
    }

    // MARK: Pro content

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 10) {
            StatTile(value: DurationText.short(minutes: weekMinutes), label: String(localized: "Focused, last 7 days"))
            StatTile(value: "\(doneThisWeek)", label: String(localized: "Done, last 7 days"))
        }

        SectionLabel("Focus minutes")
        VStack(alignment: .leading) {
            if weekMinutes == 0 {
                Text("No focus sessions this week yet. Even 5 minutes shows up here.")
                    .themeFont(.body)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(week) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Minutes", day.minutes)
                    )
                    .foregroundStyle(Theme.red)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.line)
                        AxisValueLabel().foregroundStyle(Theme.muted)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("Focus minutes per day for the last 7 days")
            }
        }
        .padding(Theme.spacingM)
        .themeCard()

        SectionLabel("Your time sense")
        VStack(alignment: .leading, spacing: 8) {
            calibration
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }

    @ViewBuilder
    private var calibration: some View {
        switch stats.verdict {
        case .notEnoughData:
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(stats.sampleCount)/\(EstimateStats.minimumSamples)")
                    .themeFont(.statNumber)
                    .foregroundStyle(Theme.red)
                Text("tasks measured")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
            }
            Text("Add a time guess to tasks and focus on them. After \(EstimateStats.minimumSamples), you'll see how your guesses compare with reality.")
                .themeFont(.body)
                .foregroundStyle(Theme.text)
        case .onTarget:
            Text("On target")
                .themeFont(.cardTitle)
                .foregroundStyle(Theme.red)
            Text("Your guesses land within 10 percent of reality.")
                .themeFont(.body)
                .foregroundStyle(Theme.text)
        case .underestimates(let percent):
            Text(verbatim: "+\(percent.formatted(.percent))")
                .themeFont(.statNumber)
                .foregroundStyle(Theme.red)
            Text("Tasks take you about \(percent.formatted(.percent)) longer than you guess.")
                .themeFont(.body)
                .foregroundStyle(Theme.text)
            if let s = stats.suggestedMinutes(for: 30) {
                Text("If it feels like 30 minutes, plan for about \(s).")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
            }
        case .overestimates(let percent):
            Text(verbatim: "−\(percent.formatted(.percent))")
                .themeFont(.statNumber)
                .foregroundStyle(Theme.red)
            Text("You finish about \(percent.formatted(.percent)) faster than you guess.")
                .themeFont(.body)
                .foregroundStyle(Theme.text)
            if let s = stats.suggestedMinutes(for: 30) {
                Text("A “30 minute” task is closer to \(s) for you.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
            }
        }
        Text("Based on \(stats.sampleCount) tasks with a guess and at least 1 minute of focus.")
            .themeFont(.detail)
            .foregroundStyle(Theme.muted)
    }

    // MARK: Locked

    @ViewBuilder
    private var locked: some View {
        Callout(title: "Pro feature", message: "Insights is part of NowNext Pro, a one-time unlock.")
        SectionLabel("What you get")
        OptionRow(title: String(localized: "Focus by day"),
                  detail: String(localized: "Minutes focused each day and tasks finished each week."),
                  showsChevron: false) {
            IconTile(symbol: "chart.bar.fill", color: Theme.red)
        }
        .padding(.horizontal, 14)
        .themeCard()
        OptionRow(title: String(localized: "Time-sense calibration"),
                  detail: String(localized: "See how your time guesses compare with reality, so plans match your actual day."),
                  showsChevron: false) {
            IconTile(symbol: "scope", color: Theme.red)
        }
        .padding(.horizontal, 14)
        .themeCard()
    }
}
