import Foundation
import Testing
@testable import NowNext

private var utc: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    c.firstWeekday = 1
    return c
}

/// Builds a UTC date.
private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

struct RecurrenceTests {
    // 2026-10-05 is a Monday.
    let monday = day(2026, 10, 5)

    @Test func dailyOccursEveryDayFromStart() {
        let rule = RecurrenceRule(cadence: .daily, start: monday)
        #expect(rule.occurs(on: monday, calendar: utc))
        #expect(rule.occurs(on: day(2026, 10, 9), calendar: utc))
        #expect(!rule.occurs(on: day(2026, 10, 4), calendar: utc)) // before start
    }

    @Test func weekdaysSkipsWeekend() {
        let rule = RecurrenceRule(cadence: .weekdays, start: monday)
        #expect(rule.occurs(on: day(2026, 10, 9), calendar: utc))   // Fri
        #expect(!rule.occurs(on: day(2026, 10, 10), calendar: utc)) // Sat
        #expect(!rule.occurs(on: day(2026, 10, 11), calendar: utc)) // Sun
    }

    @Test func weeklyOnChosenDays() {
        let rule = RecurrenceRule(cadence: .weekly([2, 4]), start: monday) // Mon, Wed
        #expect(rule.occurs(on: monday, calendar: utc))
        #expect(!rule.occurs(on: day(2026, 10, 6), calendar: utc))
        #expect(rule.occurs(on: day(2026, 10, 7), calendar: utc))
        #expect(rule.nextOccurrence(onOrAfter: day(2026, 10, 8), calendar: utc) == day(2026, 10, 12))
    }

    @Test func monthlyClampsToLastDay() {
        let rule = RecurrenceRule(cadence: .monthly(day: 31), start: day(2026, 1, 1))
        #expect(rule.occurs(on: day(2026, 2, 28), calendar: utc))
        #expect(!rule.occurs(on: day(2026, 2, 27), calendar: utc))
        #expect(rule.occurs(on: day(2026, 3, 31), calendar: utc))
    }

    @Test func everyNDaysCountsFromStart() {
        let rule = RecurrenceRule(cadence: .everyNDays(3), start: monday)
        #expect(rule.occurs(on: monday, calendar: utc))
        #expect(!rule.occurs(on: day(2026, 10, 6), calendar: utc))
        #expect(rule.occurs(on: day(2026, 10, 8), calendar: utc))
    }

    @Test func spawnRulesNeverStackOrBackfill() {
        let rule = RecurrenceRule(cadence: .daily, start: monday)
        let today = day(2026, 10, 7)
        #expect(RoutineSchedule.shouldSpawn(rule: rule, isPaused: false, lastSpawnedDay: day(2026, 10, 5),
                                            hasOpenTask: false, today: today, calendar: utc))
        // Already made today
        #expect(!RoutineSchedule.shouldSpawn(rule: rule, isPaused: false, lastSpawnedDay: today,
                                             hasOpenTask: false, today: today, calendar: utc))
        // Yesterday's copy still open: don't pile up
        #expect(!RoutineSchedule.shouldSpawn(rule: rule, isPaused: false, lastSpawnedDay: day(2026, 10, 6),
                                             hasOpenTask: true, today: today, calendar: utc))
        // Paused
        #expect(!RoutineSchedule.shouldSpawn(rule: rule, isPaused: true, lastSpawnedDay: nil,
                                             hasOpenTask: false, today: today, calendar: utc))
    }
}

struct CountdownTests {
    let now = day(2026, 10, 8, 14, 0) // Thu 2:00 PM

    @Test func minutesWhenUnderAnHour() {
        let c = Countdown.make(start: day(2026, 10, 8, 14, 25), end: nil, isAllDay: false, now: now, calendar: utc)
        #expect(c.value == "25")
        #expect(c.horizon == .today)
        #expect(c.isSoon)
    }

    @Test func hoursAndMinutesLaterToday() {
        let c = Countdown.make(start: day(2026, 10, 8, 17, 20), end: nil, isAllDay: false, now: now, calendar: utc)
        #expect(c.value == "3h 20m")
        #expect(!c.isSoon)
    }

    @Test func happeningNow() {
        let c = Countdown.make(start: day(2026, 10, 8, 13, 30), end: day(2026, 10, 8, 15, 0), isAllDay: false, now: now, calendar: utc)
        #expect(c.horizon == .now)
    }

    @Test func allDayToday() {
        let c = Countdown.make(start: day(2026, 10, 8), end: day(2026, 10, 9), isAllDay: true, now: now, calendar: utc)
        #expect(c.horizon == .today)
        #expect(c.days == 0)
    }

    @Test func daysUseCalendarDaysNotHours() {
        // 9 AM tomorrow is "1 day", even though it's only 19 hours away.
        let c = Countdown.make(start: day(2026, 10, 9, 9, 0), end: nil, isAllDay: false, now: now, calendar: utc)
        #expect(c.days == 1)
        #expect(c.horizon == .tomorrow)
    }

    @Test func horizonsAndUnits() {
        let thisWeek = Countdown.make(start: day(2026, 10, 12), end: nil, isAllDay: true, now: now, calendar: utc)
        #expect(thisWeek.value == "4")
        #expect(thisWeek.horizon == .thisWeek)

        let nextWeek = Countdown.make(start: day(2026, 10, 17), end: nil, isAllDay: true, now: now, calendar: utc)
        #expect(nextWeek.horizon == .nextWeek)

        let weeks = Countdown.make(start: day(2026, 11, 5), end: nil, isAllDay: true, now: now, calendar: utc)
        #expect(weeks.value == "4") // 28 days
        #expect(weeks.horizon == .later)

        let months = Countdown.make(start: day(2027, 1, 8), end: nil, isAllDay: true, now: now, calendar: utc)
        #expect(months.value == "3")
    }

    @Test func timelineDropsPastAndCountsDays() {
        let items = [
            UpcomingItem(id: "past", title: "Past", start: day(2026, 10, 8, 9), end: day(2026, 10, 8, 10), isAllDay: false, source: .manual(UUID())),
            UpcomingItem(id: "b", title: "B", start: day(2026, 10, 10, 9), end: nil, isAllDay: false, source: .manual(UUID())),
            UpcomingItem(id: "a", title: "A", start: day(2026, 10, 8, 16), end: nil, isAllDay: false, source: .manual(UUID())),
        ]
        let upcoming = UpcomingTimeline.upcoming(items, now: now, calendar: utc)
        #expect(upcoming.map(\.id) == ["a", "b"])
        #expect(UpcomingTimeline.dayCounts(upcoming, days: 4, now: now, calendar: utc) == [1, 0, 1, 0])
    }
}

struct CalendarGridTests {
    @Test func monthGridStartsOnFirstWeekdayAndHas42Days() {
        // October 2026 starts on a Thursday; Sunday-first grid starts Sep 27.
        let grid = CalendarGrid.monthGrid(for: day(2026, 10, 15), calendar: utc)
        #expect(grid.count == 42)
        #expect(grid.first == day(2026, 9, 27))
        #expect(grid.contains(day(2026, 10, 31)))
    }

    @Test func weekDaysAreSevenStartingSunday() {
        let week = CalendarGrid.weekDays(containing: day(2026, 10, 8), calendar: utc)
        #expect(week.count == 7)
        #expect(week.first == day(2026, 10, 4))
        #expect(week.last == day(2026, 10, 10))
    }

    @Test func shiftMovesByScope() {
        let a = day(2026, 10, 8)
        #expect(CalendarGrid.shift(a, by: 1, scope: .month, calendar: utc) == day(2026, 11, 8))
        #expect(CalendarGrid.shift(a, by: -1, scope: .week, calendar: utc) == day(2026, 10, 1))
        #expect(CalendarGrid.shift(a, by: 1, scope: .day, calendar: utc) == day(2026, 10, 9))
    }

    @Test func itemsOnDayIncludesMultiDayAndSortsAllDayFirst() {
        let trip = UpcomingItem(id: "trip", title: "Trip", start: day(2026, 10, 7), end: day(2026, 10, 10), isAllDay: true, source: .manual(UUID()))
        let call = UpcomingItem(id: "call", title: "Call", start: day(2026, 10, 8, 9), end: day(2026, 10, 8, 10), isAllDay: false, source: .manual(UUID()))
        let other = UpcomingItem(id: "other", title: "Other", start: day(2026, 10, 9, 9), end: nil, isAllDay: false, source: .manual(UUID()))
        let onEighth = CalendarGrid.items(on: day(2026, 10, 8), from: [call, other, trip], calendar: utc)
        #expect(onEighth.map(\.id) == ["trip", "call"])
    }

    @Test func overlappingEventsGetSideBySideColumns() {
        let a = UpcomingItem(id: "a", title: "A", start: day(2026, 10, 8, 9), end: day(2026, 10, 8, 10), isAllDay: false, source: .manual(UUID()))
        let b = UpcomingItem(id: "b", title: "B", start: day(2026, 10, 8, 9, 30), end: day(2026, 10, 8, 11), isAllDay: false, source: .manual(UUID()))
        let c = UpcomingItem(id: "c", title: "C", start: day(2026, 10, 8, 13), end: day(2026, 10, 8, 14), isAllDay: false, source: .manual(UUID()))
        let p = CalendarGrid.dayPlacements([c, b, a])
        #expect(p.map(\.item.id) == ["a", "b", "c"])
        #expect(p.map(\.column) == [0, 1, 0])
        #expect(p.map(\.columns) == [2, 2, 1])
    }
}

struct MergeTests {
    @Test func scheduledTaskReplacesItsCalendarCopy() {
        let start = day(2026, 10, 9, 15)
        let copy = UpcomingItem(id: "cal-x", title: "Call dentist", start: start, end: nil, isAllDay: false,
                                source: .calendar(name: "Home"), externalID: "EV1")
        let other = UpcomingItem(id: "cal-y", title: "Soccer", start: start, end: nil, isAllDay: false,
                                 source: .calendar(name: "Home"), externalID: "EV2")
        let task = UpcomingItem(id: "task-1", title: "Call dentist", start: start, end: nil, isAllDay: false,
                                source: .task(UUID()), externalID: "EV1")
        let merged = UpcomingTimeline.merge(calendar: [copy, other], nowNext: [task])
        #expect(merged.map(\.id) == ["cal-y", "task-1"])
    }
}

struct OverdueTests {
    @Test func finishedTaskCopyStaysHiddenAndOverdueReads() {
        let copy = UpcomingItem(id: "cal-x", title: "Done thing", start: day(2026, 10, 9, 15), end: nil, isAllDay: false,
                                source: .calendar(name: "Home"), externalID: "EV9")
        #expect(UpcomingTimeline.merge(calendar: [copy], nowNext: [], linkedIDs: ["EV9"]).isEmpty)
        let now = day(2026, 10, 9, 16)
        #expect(Countdown.scheduledPhrase(at: day(2026, 10, 9, 15), isAllDay: false, now: now, calendar: utc) == "overdue")
        #expect(Countdown.scheduledPhrase(at: day(2026, 10, 10, 9), isAllDay: false, now: now, calendar: utc) == "tomorrow")
    }
}
