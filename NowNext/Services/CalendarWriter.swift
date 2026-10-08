import EventKit
import Foundation
import SwiftData

/// Writes scheduled tasks to the user's iPhone calendar (iCloud, Google, Outlook…).
/// Only touches events NowNext created itself.
@MainActor
enum CalendarWriter {
    private static let store = EKEventStore()

    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static var isDenied: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .denied, .restricted: return true
        default: return false
        }
    }

    /// Asks for calendar access in context (when the user turns on "Also add to calendar").
    static func requestAccess() async -> Bool {
        if hasAccess { return true }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    struct CalendarChoice: Identifiable, Hashable {
        let id: String
        let title: String
        let source: String
    }

    /// Calendars the user can add events to.
    static func writableCalendars() -> [CalendarChoice] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title, source: $0.source?.title ?? "") }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    static var defaultCalendarID: String? {
        guard hasAccess else { return nil }
        return store.defaultCalendarForNewEvents?.calendarIdentifier
    }

    /// Creates or updates the calendar copy of a scheduled task. Returns its eventIdentifier.
    static func upsert(task: TaskItem, calendarID: String?) throws -> String? {
        guard hasAccess, let start = task.scheduledAt else { return nil }

        let event: EKEvent
        if let existingID = task.calendarEventID, let existing = store.event(withIdentifier: existingID) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.notes = String(localized: "Added from NowNext")
        }

        event.title = task.title
        event.isAllDay = task.scheduledAllDay
        if task.scheduledAllDay {
            let day = Calendar.current.startOfDay(for: start)
            event.startDate = day
            event.endDate = day
        } else {
            event.startDate = start
            let minutes = max(task.estimateMinutes ?? 30, 5)
            event.endDate = start.addingTimeInterval(Double(minutes) * 60)
        }

        if let calendarID, let cal = store.calendar(withIdentifier: calendarID), cal.allowsContentModifications {
            event.calendar = cal
        } else if event.calendar == nil {
            event.calendar = store.defaultCalendarForNewEvents
        }
        guard event.calendar != nil else { return nil }

        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    /// Removes the calendar copy NowNext created (no-op if it's already gone).
    static func remove(eventID: String?) {
        guard hasAccess, let eventID, let event = store.event(withIdentifier: eventID) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
    }

    /// The store events are fetched from, so the system edit screen saves to the same place.
    static var eventStore: EKEventStore { store }

    /// Finds one occurrence of an iPhone calendar event. Recurring events share an
    /// identifier, so match on the start date too; otherwise we'd open the first occurrence.
    static func event(withID eventID: String, start: Date) -> EKEvent? {
        guard hasAccess else { return nil }
        let cal = Calendar.current
        let from = cal.startOfDay(for: start)
        let to = cal.date(byAdding: .day, value: 2, to: from) ?? start.addingTimeInterval(2 * 86_400)
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        if let match = store.events(matching: predicate).first(where: {
            $0.eventIdentifier == eventID && abs($0.startDate.timeIntervalSince(start)) < 1
        }) {
            return match
        }
        return store.event(withIdentifier: eventID)
    }

    static func calendarID(forEvent eventID: String?) -> String? {
        guard hasAccess, let eventID else { return nil }
        return store.event(withIdentifier: eventID)?.calendar?.calendarIdentifier
    }
}
