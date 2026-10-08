import ActivityKit
import Foundation

/// Starts, updates and ends the focus Live Activity. Fails silently if the
/// user has Live Activities turned off — the in-app timer still works.
@MainActor
enum LiveActivityService {
    static func start(taskTitle: String, state: FocusActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAll()
        let attributes = FocusActivityAttributes(taskTitle: taskTitle)
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: state.endDate),
            pushType: nil
        )
    }

    static func update(_ state: FocusActivityAttributes.ContentState) {
        for activity in Activity<FocusActivityAttributes>.activities {
            Task {
                await activity.update(ActivityContent(state: state, staleDate: state.endDate))
            }
        }
    }

    static func endAll() {
        for activity in Activity<FocusActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
