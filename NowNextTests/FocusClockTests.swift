import Foundation
import Testing
@testable import NowNext

struct FocusClockTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func countsDownFromPlanned() {
        let clock = FocusClock(planned: 600, start: t0)
        #expect(clock.isRunning)
        #expect(clock.remaining(at: t0) == 600)
        #expect(clock.remaining(at: t0 + 60) == 540)
        #expect(clock.progress(at: t0 + 300) == 0.5)
        #expect(clock.endDate == t0 + 600)
    }

    @Test func pauseFreezesTime() {
        var clock = FocusClock(planned: 600, start: t0)
        clock.pause(at: t0 + 100)
        #expect(!clock.isRunning)
        #expect(clock.endDate == nil)
        #expect(clock.remaining(at: t0 + 10_000) == 500)
    }

    @Test func resumeContinuesFromPause() {
        var clock = FocusClock(planned: 600, start: t0)
        clock.pause(at: t0 + 100)
        clock.resume(at: t0 + 1_000)
        #expect(clock.remaining(at: t0 + 1_000) == 500)
        #expect(clock.endDate == t0 + 1_500)
        #expect(clock.elapsed(at: t0 + 1_100) == 200)
    }

    @Test func extendAddsTime() {
        var clock = FocusClock(planned: 600, start: t0)
        clock.extend(by: 300)
        #expect(clock.remaining(at: t0) == 900)
        #expect(clock.endDate == t0 + 900)
    }

    @Test func finishesAndNeverGoesNegative() {
        let clock = FocusClock(planned: 60, start: t0)
        #expect(!clock.isFinished(at: t0 + 59))
        #expect(clock.isFinished(at: t0 + 60))
        #expect(clock.remaining(at: t0 + 9_999) == 0)
        #expect(clock.elapsed(at: t0 + 9_999) == 60)
        #expect(clock.progress(at: t0 + 9_999) == 1)
    }

    @Test func survivesEncodingRoundTrip() throws {
        var clock = FocusClock(planned: 600, start: t0)
        clock.pause(at: t0 + 42)
        let data = try JSONEncoder().encode(clock)
        let decoded = try JSONDecoder().decode(FocusClock.self, from: data)
        #expect(decoded == clock)
    }

    @Test func clockStringFormats() {
        #expect(TimeInterval(65).clockString == "1:05")
        #expect(TimeInterval(3_725).clockString == "1:02:05")
        #expect(TimeInterval(0).clockString == "0:00")
    }
}
