import Foundation
import ActivityKit

/// Live Activity shown on the Lock Screen / Dynamic Island while a focus session runs.
struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the timer will hit zero. `nil` while paused.
        var endDate: Date?
        /// Seconds left when paused (ignored while running).
        var pausedRemaining: Int
        /// Total planned seconds, used to draw progress.
        var plannedSeconds: Int

        var isPaused: Bool { endDate == nil }

        /// A date range whose length equals the planned duration and which ends at `endDate`,
        /// so a count-down progress view shows the true fraction remaining.
        var displayRange: ClosedRange<Date>? {
            guard let endDate else { return nil }
            let start = endDate.addingTimeInterval(-Double(max(plannedSeconds, 1)))
            return start...endDate
        }

        var pausedFractionRemaining: Double {
            guard plannedSeconds > 0 else { return 0 }
            return min(1, max(0, Double(pausedRemaining) / Double(plannedSeconds)))
        }
    }

    var taskTitle: String
}
