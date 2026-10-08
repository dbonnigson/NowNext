import SwiftData
import SwiftUI

/// Pro tab: Upcoming (time-until view), Routines (recurring tasks) and Insights.
struct PlanView: View {
    enum PlanSection: String, CaseIterable, Identifiable {
        case upcoming, routines, insights
        var id: String { rawValue }

        var title: String {
            switch self {
            case .upcoming: String(localized: "Upcoming")
            case .routines: String(localized: "Routines")
            case .insights: String(localized: "Insights")
            }
        }

        var symbol: String {
            switch self {
            case .upcoming: "hourglass"
            case .routines: "repeat"
            case .insights: "chart.bar.fill"
            }
        }
    }

    @Environment(PurchaseManager.self) private var purchases
    @Environment(Router.self) private var router

    @State private var section: PlanSection = .upcoming
    @State private var showAddEvent = false
    @State private var showNewRoutine = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    ScreenTitle("Plan")
                    if purchases.isPro {
                        sectionPicker
                        switch section {
                        case .upcoming: UpcomingSection()
                        case .routines: RoutinesSection()
                        case .insights: InsightsSection()
                        }
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
                bottomBar
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventSheet()
                    .themedSheet()
            }
            .sheet(isPresented: $showNewRoutine) {
                RoutineEditorSheet(routine: nil)
                    .themedSheet()
            }
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(PlanSection.allCases) { s in
                SelectTile(title: s.title, symbol: s.symbol, isSelected: section == s) {
                    section = s
                }
            }
        }
        .sensoryFeedback(.selection, trigger: section)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !purchases.isPro {
            BottomActionBar {
                Button("Unlock Pro") { router.showPaywall = true }
                    .buttonStyle(.primary)
            }
        } else if section == .upcoming {
            BottomActionBar {
                Button { showAddEvent = true } label: { Label("Add event", systemImage: "plus") }
                    .buttonStyle(.primary)
            }
        } else if section == .routines {
            BottomActionBar {
                Button { showNewRoutine = true } label: { Label("New routine", systemImage: "plus") }
                    .buttonStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private var locked: some View {
        Callout(title: "Pro feature", message: "Plan is part of NowNext Pro, a one-time unlock.")
        SectionLabel("What you get")
        lockedRow("hourglass", String(localized: "Upcoming, as a countdown"),
                  String(localized: "Your calendar shown as time left: 45 min, 3 days, 2 weeks. Not another grid of dates."))
        lockedRow("repeat", String(localized: "Routines"),
                  String(localized: "Tasks that come back on their own: daily, weekdays, weekly or monthly. Missed days never pile up."))
        lockedRow("chart.bar.fill", String(localized: "Insights"),
                  String(localized: "Focus by day and how your time guesses compare with reality."))
    }

    private func lockedRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        OptionRow(title: title, detail: detail, showsChevron: false) {
            IconTile(symbol: symbol, color: Theme.red)
        }
        .padding(.horizontal, 14)
        .themeCard()
    }
}
