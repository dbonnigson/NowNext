import Foundation

/// Time-until math for the Upcoming view. Answers "how long do I have?"
/// instead of "what's on the 14th?", which is easier for time-blind brains.
struct Countdown: Equatable {
    enum Horizon: Int, CaseIterable, Comparable {
        case now, today, tomorrow, thisWeek, nextWeek, later

        static func < (a: Horizon, b: Horizon) -> Bool { a.rawValue < b.rawValue }

        var title: String {
            switch self {
            case .now: String(localized: "Happening now")
            case .today: String(localized: "Today")
            case .tomorrow: String(localized: "Tomorrow")
            case .thisWeek: String(localized: "This week")
            case .nextWeek: String(localized: "Next week")
            case .later: String(localized: "Later")
            }
        }
    }

    /// Big number or phrase, e.g. "45", "3h 20m", "6".
    let value: String
    /// Short unit under the number, e.g. "MIN", "TO GO", "DAYS".
    let unit: String
    let horizon: Horizon
    /// Within 30 minutes: time to start getting ready.
    let isSoon: Bool
    /// Whole calendar days from today (0 = today).
    let days: Int
    /// Plain-language version: "in 45 min", "in 3h 20m", "today", "tomorrow", "in 6 days".
    let phrase: String

    static func make(
        start: Date,
        end: Date?,
        isAllDay: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> Countdown {
        let endDate = end ?? start
        if isAllDay && calendar.isDate(start, inSameDayAs: now) {
            return Countdown(value: String(localized: "Today"), unit: String(localized: "All day"), horizon: .today, isSoon: false, days: 0, phrase: String(localized: "today"))
        }
        if now >= start && now < endDate {
            return Countdown(value: String(localized: "Now"), unit: String(localized: "On"), horizon: .now, isSoon: true, days: 0, phrase: String(localized: "happening now"))
        }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: start)
        ).day ?? 0

        if days <= 0 {
            if isAllDay {
                return Countdown(value: String(localized: "Today"), unit: String(localized: "All day"), horizon: .today, isSoon: false, days: 0, phrase: String(localized: "today"))
            }
            let minutes = max(0, Int((start.timeIntervalSince(now) / 60).rounded(.up)))
            if minutes < 60 {
                return Countdown(value: "\(minutes)", unit: String(localized: "Min"), horizon: .today, isSoon: minutes <= 30, days: 0, phrase: String(localized: "in \(minutes) min"))
            }
            let h = minutes / 60
            let m = minutes % 60
            let value = m == 0 ? "\(h)h" : "\(h)h \(m)m"
            return Countdown(value: value, unit: String(localized: "To go"), horizon: .today, isSoon: false, days: 0, phrase: String(localized: "in \(value)"))
        }

        let horizon: Horizon
        switch days {
        case 1: horizon = .tomorrow
        case 2...6: horizon = .thisWeek
        case 7...13: horizon = .nextWeek
        default: horizon = .later
        }

        if days < 14 {
            return Countdown(
                value: "\(days)",
                unit: days == 1 ? String(localized: "Day") : String(localized: "Days"),
                horizon: horizon, isSoon: false, days: days,
                phrase: days == 1 ? String(localized: "tomorrow") : String(localized: "in \(days) days")
            )
        }
        if days < 60 {
            let weeks = days / 7
            return Countdown(value: "\(weeks)", unit: String(localized: "Weeks"), horizon: horizon, isSoon: false, days: days, phrase: String(localized: "in \(weeks) weeks"))
        }
        let months = max(2, days / 30)
        return Countdown(value: "\(months)", unit: String(localized: "Months"), horizon: horizon, isSoon: false, days: days, phrase: String(localized: "in \(months) months"))
    }
}

/// One item in the Upcoming list, from the user's calendar or added by hand.
struct UpcomingItem: Identifiable, Equatable {
    enum Source: Equatable {
        case calendar(name: String)
        case manual(UUID)
    }

    let id: String
    let title: String
    let start: Date
    let end: Date?
    let isAllDay: Bool
    let source: Source

    var isManual: Bool {
        if case .manual = source { return true }
        return false
    }
}

enum UpcomingTimeline {
    /// Drops finished items, sorts soonest first.
    static func upcoming(_ items: [UpcomingItem], now: Date, calendar: Calendar = .current) -> [UpcomingItem] {
        items
            .filter { item in
                if item.isAllDay {
                    return calendar.startOfDay(for: item.start) >= calendar.startOfDay(for: now)
                }
                return (item.end ?? item.start) > now
            }
            .sorted { $0.start < $1.start }
    }

    /// Event counts for each of the next `days` days (index 0 = today).
    static func dayCounts(_ items: [UpcomingItem], days: Int, now: Date, calendar: Calendar = .current) -> [Int] {
        var counts = Array(repeating: 0, count: max(days, 0))
        let today = calendar.startOfDay(for: now)
        for item in items {
            let d = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: item.start)).day ?? -1
            if d >= 0 && d < counts.count { counts[d] += 1 }
        }
        return counts
    }
}
