import Foundation
import Testing
@testable import NowNext

struct PlannerLogicTests {
    @Test func nowLimitIsEnforced() {
        #expect(PlannerLogic.canAddToNow(currentNowCount: 0, limit: 3))
        #expect(PlannerLogic.canAddToNow(currentNowCount: 2, limit: 3))
        #expect(!PlannerLogic.canAddToNow(currentNowCount: 3, limit: 3))
    }

    @Test func nowLimitIsClamped() {
        #expect(PlannerLogic.clampedLimit(0) == 1)
        #expect(PlannerLogic.clampedLimit(99) == 5)
        #expect(!PlannerLogic.canAddToNow(currentNowCount: 5, limit: 50))
    }

    @Test func appendIndexGoesToEnd() {
        #expect(PlannerLogic.appendIndex(after: []) == 1)
        #expect(PlannerLogic.appendIndex(after: [3, 1, 7]) == 8)
    }
}

struct BrainDumpParserTests {
    @Test func splitsLinesAndDropsBlanks() {
        let text = "buy milk\n\n  call mom  \n"
        #expect(BrainDumpParser.parse(text) == ["buy milk", "call mom"])
    }

    @Test func stripsListMarkers() {
        let text = """
        - email Sam
        * file taxes
        • book dentist
        1. pay rent
        12) water plants
        [ ] fold laundry
        """
        #expect(BrainDumpParser.parse(text) == [
            "email Sam", "file taxes", "book dentist", "pay rent", "water plants", "fold laundry",
        ])
    }

    @Test func keepsNumbersThatAreNotMarkers() {
        #expect(BrainDumpParser.parse("3 emails to answer") == ["3 emails to answer"])
    }

    @Test func capsVeryLongLines() {
        let long = String(repeating: "a", count: 500)
        #expect(BrainDumpParser.parse(long).first?.count == BrainDumpParser.maxTitleLength)
    }
}

struct EstimateStatsTests {
    @Test func needsMinimumSamples() {
        let stats = EstimateStats(samples: [
            .init(estimateMinutes: 10, trackedSeconds: 900),
            .init(estimateMinutes: 10, trackedSeconds: 900),
        ])
        #expect(stats.multiplier == nil)
        #expect(stats.verdict == .notEnoughData)
    }

    @Test func detectsUnderestimating() {
        // Guessed 30m total, took 45m total → 1.5x.
        let stats = EstimateStats(samples: [
            .init(estimateMinutes: 10, trackedSeconds: 15 * 60),
            .init(estimateMinutes: 10, trackedSeconds: 15 * 60),
            .init(estimateMinutes: 10, trackedSeconds: 15 * 60),
        ])
        #expect(stats.sampleCount == 3)
        #expect(stats.multiplier == 1.5)
        #expect(stats.verdict == .underestimates(percent: 50))
        #expect(stats.suggestedMinutes(for: 30) == 45)
    }

    @Test func ignoresTasksWithoutRealFocus() {
        let stats = EstimateStats(samples: [
            .init(estimateMinutes: 10, trackedSeconds: 30), // < 1 minute, ignored
            .init(estimateMinutes: 10, trackedSeconds: 600),
            .init(estimateMinutes: 10, trackedSeconds: 600),
            .init(estimateMinutes: 10, trackedSeconds: 600),
        ])
        #expect(stats.sampleCount == 3)
        #expect(stats.verdict == .onTarget)
    }

    @Test func detectsOverestimating() {
        let stats = EstimateStats(samples: Array(repeating: .init(estimateMinutes: 20, trackedSeconds: 10 * 60), count: 3))
        #expect(stats.verdict == .overestimates(percent: 50))
    }
}

struct FocusHistoryTests {
    @Test func returnsZeroFilledDaysOldestFirst() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_790_000_000) // fixed moment
        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let days = FocusHistory.lastDays(3, entries: [
            .init(endedAt: now, focusedSeconds: 25 * 60),
            .init(endedAt: yesterday.addingTimeInterval(3600), focusedSeconds: 10 * 60),
            .init(endedAt: yesterday.addingTimeInterval(7200), focusedSeconds: 5 * 60),
        ], now: now, calendar: cal)

        #expect(days.count == 3)
        #expect(days.map(\.minutes) == [0, 15, 25])
        #expect(days.last?.date == today)
    }
}
