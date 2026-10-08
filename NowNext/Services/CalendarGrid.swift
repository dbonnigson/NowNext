import Foundation

/// Countdown (time-until) vs. a traditional calendar in Plan › Upcoming.
enum UpcomingMode: String, CaseIterable, Identifiable {
    case countdown, calendar
    var id: String { rawValue }

    var title: String {
        switch self {
        case .countdown: String(localized: "Countdown")
        case .calendar: String(localized: "Calendar")
        }
    }

    var symbol: String {
        switch self {
        case .countdown: "hourglass"
        case .calendar: "calendar"
        }
    }
}

enum CalendarScope: String, CaseIterable, Identifiable {
    case month, week, day
    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: String(localized: "Month")
        case .week: String(localized: "Week")
        case .day: String(localized: "Day")
        }
    }

    var component: Calendar.Component {
        switch self {
        case .month: .month
        case .week: .weekOfYear
        case .day: .day
        }
    }
}

/// Pure date math for the month / week / day views. Unit-tested.
enum CalendarGrid {
    /// 42 days (6 full weeks) covering the month that contains `anchor`,
    /// starting on the locale's first weekday.
    static func monthGrid(for anchor: Date, calendar: Calendar = .current) -> [Date] {
        guard let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// The 7 days of the week containing `anchor`.
    static func weekDays(containing anchor: Date, calendar: Calendar = .current) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Date range to load events for.
    static func range(for scope: CalendarScope, anchor: Date, calendar: Calendar = .current) -> DateInterval {
        switch scope {
        case .month:
            let grid = monthGrid(for: anchor, calendar: calendar)
            guard let first = grid.first, let last = grid.last,
                  let end = calendar.date(byAdding: .day, value: 1, to: last) else {
                return DateInterval(start: anchor, duration: 0)
            }
            return DateInterval(start: first, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: anchor) ?? DateInterval(start: anchor, duration: 0)
        case .day:
            return calendar.dateInterval(of: .day, for: anchor) ?? DateInterval(start: anchor, duration: 0)
        }
    }

    /// Move one month / week / day forward (+1) or back (-1).
    static func shift(_ anchor: Date, by value: Int, scope: CalendarScope, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: scope.component, value: value, to: anchor) ?? anchor
    }

    /// Items that touch the given calendar day (multi-day events appear on every day they cover).
    static func items(on day: Date, from items: [UpcomingItem], calendar: Calendar = .current) -> [UpcomingItem] {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        return items
            .filter { item in
                let end = max(item.end ?? item.start.addingTimeInterval(1), item.start.addingTimeInterval(1))
                return item.start < interval.end && end > interval.start
            }
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.start < b.start
            }
    }

    /// Side-by-side columns for overlapping timed events in the day view.
    struct Placement: Equatable {
        let item: UpcomingItem
        let column: Int
        let columns: Int
    }

    static func dayPlacements(_ items: [UpcomingItem]) -> [Placement] {
        let timed = items.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        var placements: [Placement] = []
        var cluster: [(item: UpcomingItem, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func flush() {
            let count = max(columnEnds.count, 1)
            placements += cluster.map { Placement(item: $0.item, column: $0.column, columns: count) }
            cluster.removeAll()
            columnEnds.removeAll()
        }

        for item in timed {
            let end = max(item.end ?? item.start.addingTimeInterval(30 * 60), item.start.addingTimeInterval(15 * 60))
            if item.start >= clusterEnd { flush() }
            if let free = columnEnds.firstIndex(where: { $0 <= item.start }) {
                columnEnds[free] = end
                cluster.append((item, free))
            } else {
                columnEnds.append(end)
                cluster.append((item, columnEnds.count - 1))
            }
            clusterEnd = max(clusterEnd, end)
        }
        flush()
        return placements
    }
}
