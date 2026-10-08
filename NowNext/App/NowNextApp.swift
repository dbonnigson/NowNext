import SwiftData
import SwiftUI
import UserNotifications

@main
struct NowNextApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .appEnvironment()
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

/// The app-wide objects, created once.
@MainActor
enum AppServices {
    static let purchases = PurchaseManager()
    static let focus = FocusController()
    static let router = Router()
    static let calendar = CalendarService()
}

extension View {
    /// Attaches the app-wide objects. Applied at the root AND on every sheet:
    /// older SwiftUI (iOS 17, and iPhone apps running on Macs) can lose
    /// @Observable environment values across a presentation, which crashes with
    /// "No Observable object of type … found".
    func appEnvironment() -> some View {
        self
            .environment(AppServices.purchases)
            .environment(AppServices.focus)
            .environment(AppServices.router)
            .environment(AppServices.calendar)
    }
}

/// Which tab is showing. Lets any screen jump to Focus or Today.
@MainActor
@Observable
final class Router {
    enum Tab: Hashable {
        case today, brainDump, focus, plan, settings
    }

    var tab: Tab = .today
    /// Task preselected when jumping to the Focus tab from a task.
    var focusCandidateID: UUID?
    var showPaywall = false
    /// Task shown in the detail bottom sheet.
    var openTask: TaskItem?

    func focus(on task: TaskItem) {
        openTask = nil
        focusCandidateID = task.uuid
        tab = .focus
    }
}
