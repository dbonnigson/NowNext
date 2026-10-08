import Foundation
import SwiftData

/// Where a task lives in the planner.
/// Stored as a raw string on `TaskItem` so SwiftData predicates stay simple.
enum Slot: String, CaseIterable, Codable, Identifiable {
    case inbox
    case now
    case next
    case later

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: String(localized: "Brain Dump")
        case .now: String(localized: "Now")
        case .next: String(localized: "Next")
        case .later: String(localized: "Later")
        }
    }

    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .now: "bolt.fill"
        case .next: "arrow.right.circle"
        case .later: "moon.zzz"
        }
    }
}

@Model
final class TaskItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var completedAt: Date?
    var slotRaw: String = Slot.inbox.rawValue
    var sortIndex: Double = 0
    /// User's guess in minutes. `nil` means no estimate.
    var estimateMinutes: Int?
    /// Total focused seconds recorded against this task by the focus timer.
    var trackedSeconds: Int = 0
    /// Set when this task was created by a recurring Routine.
    var routineID: UUID?
    /// When the task is scheduled on the calendar (Pro). `nil` = not scheduled.
    var scheduledAt: Date?
    var scheduledAllDay: Bool = false
    /// EventKit eventIdentifier of the copy written to the user's iPhone calendar, if any.
    var calendarEventID: String?

    @Relationship(deleteRule: .cascade, inverse: \TaskStep.task)
    var steps: [TaskStep] = []

    @Relationship(deleteRule: .nullify, inverse: \FocusSession.task)
    var sessions: [FocusSession] = []

    init(title: String, slot: Slot = .inbox, sortIndex: Double = 0) {
        self.uuid = UUID()
        self.title = title
        self.slotRaw = slot.rawValue
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var slot: Slot {
        get { Slot(rawValue: slotRaw) ?? .inbox }
        set { slotRaw = newValue.rawValue }
    }

    var isDone: Bool { completedAt != nil }

    var isScheduled: Bool { scheduledAt != nil }

    var orderedSteps: [TaskStep] {
        steps.sorted { $0.sortIndex < $1.sortIndex }
    }

    var nextOpenStep: TaskStep? {
        orderedSteps.first { !$0.isDone }
    }

    var stepProgressText: String? {
        guard !steps.isEmpty else { return nil }
        let done = steps.filter(\.isDone).count
        return String(localized: "\(done)/\(steps.count) steps")
    }
}

@Model
final class TaskStep {
    var uuid: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var sortIndex: Double = 0
    var task: TaskItem?

    init(title: String, sortIndex: Double) {
        self.uuid = UUID()
        self.title = title
        self.sortIndex = sortIndex
    }
}

@Model
final class FocusSession {
    var uuid: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var plannedSeconds: Int = 0
    var focusedSeconds: Int = 0
    var task: TaskItem?

    init(startedAt: Date, endedAt: Date, plannedSeconds: Int, focusedSeconds: Int, task: TaskItem?) {
        self.uuid = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.focusedSeconds = focusedSeconds
        self.task = task
    }
}

/// A task that comes back on a schedule (Pro).
/// Each day it's due, one copy lands in "Next" (never more than one open copy).
@Model
final class Routine {
    var uuid: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    /// First day the routine can occur.
    var startDate: Date = Date()
    /// "daily", "weekdays", "weekly", "monthly", "everyNDays"
    var cadenceRaw: String = "daily"
    /// Weekly: comma-separated Calendar weekdays (1 = Sunday … 7 = Saturday).
    var weekdaysRaw: String = ""
    /// Monthly: day of month (clamped to the month's last day).
    var monthDay: Int = 1
    /// Every-N-days interval.
    var intervalDays: Int = 2
    var estimateMinutes: Int?
    var isPaused: Bool = false
    /// Day a task was last created from this routine (prevents duplicates).
    var lastSpawnedDay: Date?

    init(title: String, startDate: Date = Date()) {
        self.uuid = UUID()
        self.title = title
        self.createdAt = Date()
        self.startDate = startDate
    }
}

/// An event the user adds by hand (calendar events are read live, not stored).
@Model
final class UpcomingEvent {
    var uuid: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var isAllDay: Bool = false
    var createdAt: Date = Date()

    init(title: String, date: Date, isAllDay: Bool) {
        self.uuid = UUID()
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.createdAt = Date()
    }
}
