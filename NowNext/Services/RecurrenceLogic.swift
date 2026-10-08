import Foundation

/// How often a routine repeats. Pure value type so it can be unit-tested.
enum Cadence: Equatable {
    case daily
    case weekdays
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday. Empty means "same weekday as the start date".
    case weekly(Set<Int>)
    /// Day of month; months shorter than this use their last day.
    case monthly(day: Int)
    case everyNDays(Int)

    var kind: String {
        switch self {
        case .daily: "daily"
        case .weekdays: "weekdays"
        case .weekly: "weekly"
        case .monthly: "monthly"
        case .everyNDays: "everyNDays"
        }
    }
}

struct RecurrenceRule: Equatable {
    var cadence: Cadence
    var start: Date

    /// Does the routine fall on this calendar day?
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let d = calendar.startOfDay(for: day)
        let s = calendar.startOfDay(for: start)
        guard d >= s else { return false }

        switch cadence {
        case .daily:
            return true
        case .weekdays:
            let wd = calendar.component(.weekday, from: d)
            return (2...6).contains(wd)
        case .weekly(let days):
            let wd = calendar.component(.weekday, from: d)
            let set = days.isEmpty ? [calendar.component(.weekday, from: s)] : days
            return set.contains(wd)
        case .monthly(let dayOfMonth):
            let dom = calendar.component(.day, from: d)
            let lastDay = calendar.range(of: .day, in: .month, for: d)?.count ?? 31
            return dom == min(max(dayOfMonth, 1), lastDay)
        case .everyNDays(let n):
            guard n > 0 else { return false }
            let diff = calendar.dateComponents([.day], from: s, to: d).day ?? 0
            return diff % n == 0
        }
    }

    /// First occurrence on or after `day` (searches up to ~13 months ahead).
    func nextOccurrence(onOrAfter day: Date, calendar: Calendar = .current) -> Date? {
        var d = calendar.startOfDay(for: day)
        for _ in 0..<400 {
            if occurs(on: d, calendar: calendar) { return d }
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { return nil }
            d = next
        }
        return nil
    }
}

enum RoutineSchedule {
    /// Should a new task be created from this routine today?
    /// Never backfills missed days and never stacks a second open copy,
    /// so a skipped week doesn't turn into a pile of guilt.
    static func shouldSpawn(
        rule: RecurrenceRule,
        isPaused: Bool,
        lastSpawnedDay: Date?,
        hasOpenTask: Bool,
        today: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard !isPaused, !hasOpenTask else { return false }
        if let last = lastSpawnedDay, calendar.isDate(last, inSameDayAs: today) { return false }
        return rule.occurs(on: today, calendar: calendar)
    }

    /// "Every day", "Weekdays", "Mon, Wed, Fri", "Monthly on the 15th", "Every 3 days".
    static func describe(_ cadence: Cadence, calendar: Calendar = .current) -> String {
        switch cadence {
        case .daily:
            return String(localized: "Every day")
        case .weekdays:
            return String(localized: "Weekdays")
        case .weekly(let days):
            guard !days.isEmpty else { return String(localized: "Weekly") }
            let symbols = calendar.shortWeekdaySymbols
            let names = days.sorted().compactMap { (1...7).contains($0) ? symbols[$0 - 1] : nil }
            return names.joined(separator: ", ")
        case .monthly(let day):
            let ordinal = NumberFormatter.localizedString(from: NSNumber(value: day), number: .ordinal)
            return String(localized: "Monthly on the \(ordinal)")
        case .everyNDays(let n):
            return n == 1 ? String(localized: "Every day") : String(localized: "Every \(n) days")
        }
    }
}
