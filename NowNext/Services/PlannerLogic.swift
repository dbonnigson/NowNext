import Foundation

/// Pure, testable planning rules. No SwiftData or UI here.
enum PlannerLogic {
    static let defaultNowLimit = 3
    static let nowLimitRange = 1...5

    /// Whether another task can go into "Now".
    static func canAddToNow(currentNowCount: Int, limit: Int) -> Bool {
        currentNowCount < clampedLimit(limit)
    }

    static func clampedLimit(_ limit: Int) -> Int {
        min(max(limit, nowLimitRange.lowerBound), nowLimitRange.upperBound)
    }

    /// Sort index that places an item at the end of a list.
    static func appendIndex(after existing: [Double]) -> Double {
        (existing.max() ?? 0) + 1
    }

    /// True if `date` falls on the same calendar day as `reference`.
    static func isSameDay(_ date: Date?, as reference: Date, calendar: Calendar = .current) -> Bool {
        guard let date else { return false }
        return calendar.isDate(date, inSameDayAs: reference)
    }
}

/// Turns a messy brain dump into clean task titles.
enum BrainDumpParser {
    static let maxTitleLength = 200

    /// Splits on new lines, strips list markers ("-", "*", "•", "1.", "2)", "[ ]"),
    /// trims whitespace, and drops empty lines.
    static func parse(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map(clean)
            .filter { !$0.isEmpty }
    }

    static func clean(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = ["[ ]", "[x]", "[X]", "- ", "* ", "• ", "– ", "— "]
        var changed = true
        while changed {
            changed = false
            for p in prefixes where s.hasPrefix(p) {
                s = String(s.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
                changed = true
            }
            // Numbered markers like "1." "12)" followed by a space.
            if let range = s.range(of: #"^\d{1,3}[\.\)]\s+"#, options: .regularExpression) {
                s.removeSubrange(range)
                changed = true
            }
        }

        if s.count > maxTitleLength {
            s = String(s.prefix(maxTitleLength))
        }
        return s
    }
}

/// Compares time estimates with time actually focused, to fight time blindness.
struct EstimateStats: Equatable {
    /// Tasks that had both an estimate and at least `minimumTrackedSeconds` of focus.
    let sampleCount: Int
    /// Total actual / total estimated. 1.0 = spot on, 1.5 = took 50% longer.
    let multiplier: Double?

    static let minimumTrackedSeconds = 60
    static let minimumSamples = 3

    struct Sample: Equatable {
        let estimateMinutes: Int
        let trackedSeconds: Int
    }

    init(samples: [Sample]) {
        let usable = samples.filter {
            $0.estimateMinutes > 0 && $0.trackedSeconds >= Self.minimumTrackedSeconds
        }
        sampleCount = usable.count
        let estimated = usable.reduce(0) { $0 + $1.estimateMinutes * 60 }
        let actual = usable.reduce(0) { $0 + $1.trackedSeconds }
        multiplier = (usable.count >= Self.minimumSamples && estimated > 0)
            ? Double(actual) / Double(estimated)
            : nil
    }

    /// Estimate adjusted by the user's personal multiplier, rounded to 5 minutes.
    func suggestedMinutes(for estimate: Int) -> Int? {
        guard let multiplier, estimate > 0 else { return nil }
        let raw = Double(estimate) * multiplier
        return max(5, Int((raw / 5).rounded()) * 5)
    }

    enum Verdict: Equatable {
        case notEnoughData
        case onTarget
        case underestimates(percent: Int)
        case overestimates(percent: Int)
    }

    var verdict: Verdict {
        guard let multiplier else { return .notEnoughData }
        let percent = Int(((multiplier - 1) * 100).rounded())
        if abs(percent) <= 10 { return .onTarget }
        return percent > 0 ? .underestimates(percent: percent) : .overestimates(percent: -percent)
    }
}

/// Focus minutes grouped by day for charts.
enum FocusHistory {
    struct Day: Identifiable, Equatable {
        let date: Date
        let minutes: Int
        var id: Date { date }
    }

    struct Entry {
        let endedAt: Date
        let focusedSeconds: Int
    }

    /// Returns exactly `days` entries ending today (oldest first), zero-filled.
    static func lastDays(_ days: Int, entries: [Entry], now: Date = Date(), calendar: Calendar = .current) -> [Day] {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: Int] = [:]
        for e in entries {
            let day = calendar.startOfDay(for: e.endedAt)
            totals[day, default: 0] += e.focusedSeconds
        }
        return (0..<max(days, 0)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return Day(date: day, minutes: (totals[day] ?? 0) / 60)
        }
    }
}
