import Foundation
import Observation
import SwiftData

/// Owns the single active focus session. Persists itself so a session
/// survives the app being closed, and keeps notifications + Live Activity in sync.
@MainActor
@Observable
final class FocusController {
    struct ActiveSession: Codable, Equatable {
        var clock: FocusClock
        var taskID: UUID?
        var taskTitle: String
    }

    struct Summary: Equatable {
        let focusedSeconds: Int
        let taskID: UUID?
        let taskTitle: String
    }

    private(set) var session: ActiveSession?
    /// Set when a session finishes; the Focus screen shows a wrap-up card.
    var lastSummary: Summary?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: SettingsKey.focusState),
           let saved = try? JSONDecoder().decode(ActiveSession.self, from: data) {
            session = saved
        }
    }

    var isActive: Bool { session != nil }

    // MARK: Controls

    func start(minutes: Int, task: TaskItem?) {
        let now = Date()
        let clock = FocusClock(planned: TimeInterval(max(1, minutes) * 60), start: now)
        let title = task?.title ?? ""
        session = ActiveSession(clock: clock, taskID: task?.uuid, taskTitle: title)
        lastSummary = nil
        persist()

        LiveActivityService.start(taskTitle: title, state: activityState())
        Task {
            if await NotificationService.requestAuthorizationIfNeeded(), let end = clock.endDate {
                NotificationService.scheduleFocusEnd(at: end, taskTitle: title)
            }
        }
    }

    func pause() {
        guard var s = session else { return }
        s.clock.pause(at: Date())
        session = s
        persist()
        NotificationService.cancelFocusEnd()
        LiveActivityService.update(activityState())
    }

    func resume() {
        guard var s = session else { return }
        s.clock.resume(at: Date())
        session = s
        persist()
        rescheduleNotification()
        LiveActivityService.update(activityState())
    }

    func extend(minutes: Int) {
        guard var s = session else { return }
        s.clock.extend(by: TimeInterval(minutes * 60))
        session = s
        persist()
        rescheduleNotification()
        LiveActivityService.update(activityState())
    }

    /// Ends early. Focused time so far is still recorded — every minute counts.
    func stop(context: ModelContext) {
        finish(at: Date(), context: context)
    }

    /// Called once a second by the root view; wraps up when time runs out.
    func tick(context: ModelContext) {
        guard let s = session else { return }
        let now = Date()
        if s.clock.isFinished(at: now) {
            finish(at: s.clock.endDate ?? now, context: context)
        }
    }

    // MARK: Internals

    private func finish(at end: Date, context: ModelContext) {
        guard var s = session else { return }
        s.clock.pause(at: end)
        let focused = Int(s.clock.elapsed(at: end).rounded())
        TaskStore.recordFocus(
            taskID: s.taskID,
            startedAt: s.clock.startedAt,
            endedAt: end,
            plannedSeconds: Int(s.clock.planned),
            focusedSeconds: focused,
            context: context
        )
        lastSummary = Summary(focusedSeconds: focused, taskID: s.taskID, taskTitle: s.taskTitle)
        session = nil
        persist()
        NotificationService.cancelFocusEnd()
        LiveActivityService.endAll()
    }

    private func rescheduleNotification() {
        NotificationService.cancelFocusEnd()
        if let s = session, let end = s.clock.endDate {
            NotificationService.scheduleFocusEnd(at: end, taskTitle: s.taskTitle)
        }
    }

    private func activityState() -> FocusActivityAttributes.ContentState {
        let now = Date()
        guard let s = session else {
            return .init(endDate: nil, pausedRemaining: 0, plannedSeconds: 0)
        }
        return .init(
            endDate: s.clock.endDate,
            pausedRemaining: Int(s.clock.remaining(at: now)),
            plannedSeconds: Int(s.clock.planned)
        )
    }

    private func persist() {
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: SettingsKey.focusState)
        } else {
            defaults.removeObject(forKey: SettingsKey.focusState)
        }
    }
}
