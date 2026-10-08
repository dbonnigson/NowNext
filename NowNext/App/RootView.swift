import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusController.self) private var focus
    @Environment(Router.self) private var router

    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        RootView.configureTabBar()
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "bolt.fill") }
                .tag(Router.Tab.today)

            BrainDumpView()
                .tabItem { Label("Brain Dump", systemImage: "tray.and.arrow.down.fill") }
                .tag(Router.Tab.brainDump)

            FocusView()
                .tabItem { Label("Focus", systemImage: focus.isActive ? "timer.circle.fill" : "timer") }
                .tag(Router.Tab.focus)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                .tag(Router.Tab.insights)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Router.Tab.settings)
        }
        .tint(Theme.text)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: router.tab)
        .onReceive(ticker) { _ in
            focus.tick(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                focus.tick(context: context)
            } else if phase == .background {
                WidgetRefresher.reload()
            }
        }
        .sheet(item: $router.openTask) { task in
            TaskDetailSheet(task: task)
                .themedSheet()
        }
        .sheet(isPresented: $router.showPaywall) {
            PaywallView()
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
                .presentationCornerRadius(Theme.radiusSheet)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasOnboarded },
            set: { hasOnboarded = !$0 }
        )) {
            OnboardingView {
                hasOnboarded = true
            }
            .preferredColorScheme(.dark)
        }
    }

    /// Black tab bar with a thin top divider; selected items white, others muted.
    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.background)
        appearance.shadowColor = UIColor(Theme.surfaceRaised)
        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(Theme.muted)
        normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.muted)]
        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = UIColor(Theme.text)
        selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

/// Principal-slot rail showing how full "Now" is. Used on every tab's nav bar.
struct NowRail: View {
    @Query(filter: #Predicate<TaskItem> { $0.completedAt == nil && $0.slotRaw == "now" })
    private var nowTasks: [TaskItem]

    @AppStorage(SettingsKey.nowLimit) private var nowLimit = PlannerLogic.defaultNowLimit

    var body: some View {
        let limit = PlannerLogic.clampedLimit(nowLimit)
        ProgressRail(
            filled: min(nowTasks.count, limit),
            total: limit,
            label: String(localized: "Now \(nowTasks.count) of \(limit)")
        )
    }
}

extension View {
    /// Black nav bar with the Now rail in the center slot.
    func themedTabScreen() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NowRail()
                }
            }
    }
}
