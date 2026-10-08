import EventKit
import Foundation
import Observation

/// Read-only access to the user's iPhone calendars (iCloud, Google, Outlook, etc.).
/// Events are read on-device for display and never stored or sent anywhere.
@MainActor
@Observable
final class CalendarService {
    enum Access: Equatable {
        case notDetermined, granted, denied
    }

    private(set) var access: Access
    private(set) var items: [UpcomingItem] = []

    @ObservationIgnored private let store = EKEventStore()
    /// How far ahead to look.
    @ObservationIgnored private let horizonDays = 90

    init() {
        access = Self.currentAccess()
    }

    static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            // denied, restricted, writeOnly
            return .denied
        }
    }

    /// Asks for permission only when the user taps "Connect Calendar".
    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .granted : .denied
        } catch {
            access = .denied
        }
        refresh()
    }

    func refresh(now: Date = Date()) {
        access = Self.currentAccess()
        guard access == .granted else {
            items = []
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: horizonDays, to: start) else { return }
        items = events(from: start, to: end)
    }

    /// Events in any date range (used by the month/week/day calendar, which can look backwards).
    func events(from start: Date, to end: Date) -> [UpcomingItem] {
        guard Self.currentAccess() == .granted, end > start else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            UpcomingItem(
                id: "cal-" + (event.calendarItemIdentifier) + "-\(event.startDate.timeIntervalSince1970)",
                title: event.title ?? String(localized: "Untitled event"),
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                source: .calendar(name: event.calendar?.title ?? String(localized: "Calendar"))
            )
        }
    }
}
