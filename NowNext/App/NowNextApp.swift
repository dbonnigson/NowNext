import SwiftData
import SwiftUI
import UserNotifications

@main
struct NowNextApp: App {
    @State private var purchases = PurchaseManager()
    @State private var focus = FocusController()
    @State private var router = Router()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchases)
                .environment(focus)
                .environment(router)
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

/// Which tab is showing. Lets any screen jump to Focus or Today.
@MainActor
@Observable
final class Router {
    enum Tab: Hashable {
        case today, brainDump, focus, insights, settings
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
