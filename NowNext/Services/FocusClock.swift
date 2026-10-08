import Foundation

/// Pure timer math. Based on wall-clock dates (not ticking counters) so it stays
/// correct when the app is backgrounded, suspended or relaunched.
struct FocusClock: Codable, Equatable {
    /// Planned length of the session in seconds (grows with "+5 min").
    private(set) var planned: TimeInterval
    /// Focused time banked from previous running segments.
    private(set) var accumulated: TimeInterval = 0
    /// Start of the current running segment. `nil` while paused.
    private(set) var segmentStart: Date?
    /// When the session was first started.
    let startedAt: Date

    init(planned: TimeInterval, start: Date) {
        self.planned = max(1, planned)
        self.startedAt = start
        self.segmentStart = start
    }

    var isRunning: Bool { segmentStart != nil }

    func elapsed(at now: Date) -> TimeInterval {
        let live = segmentStart.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return min(planned, accumulated + live)
    }

    func remaining(at now: Date) -> TimeInterval {
        max(0, planned - elapsed(at: now))
    }

    /// 0 at start → 1 when finished.
    func progress(at now: Date) -> Double {
        min(1, max(0, elapsed(at: now) / planned))
    }

    func isFinished(at now: Date) -> Bool {
        remaining(at: now) <= 0
    }

    /// When the timer will reach zero if it keeps running. `nil` while paused.
    var endDate: Date? {
        guard let segmentStart else { return nil }
        return segmentStart.addingTimeInterval(planned - accumulated)
    }

    mutating func pause(at now: Date) {
        guard isRunning else { return }
        accumulated = elapsed(at: now)
        segmentStart = nil
    }

    mutating func resume(at now: Date) {
        guard !isRunning, !isFinished(at: now) else { return }
        segmentStart = now
    }

    mutating func extend(by seconds: TimeInterval) {
        guard seconds > 0 else { return }
        planned += seconds
    }
}

extension TimeInterval {
    /// "12:05" or "1:02:05".
    var clockString: String {
        let total = Int(self.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

enum DurationText {
    /// "45m", "1h 20m", "under 1m".
    static func short(seconds: Int) -> String {
        if seconds < 60 { return String(localized: "under 1m") }
        let minutes = seconds / 60
        if minutes < 60 { return String(localized: "\(minutes)m") }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? String(localized: "\(h)h") : String(localized: "\(h)h \(m)m")
    }

    static func short(minutes: Int) -> String {
        short(seconds: minutes * 60)
    }
}
