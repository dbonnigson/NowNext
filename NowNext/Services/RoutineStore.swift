import Foundation
import SwiftData

extension Routine {
    var cadence: Cadence {
        get {
            switch cadenceRaw {
            case "weekdays": return .weekdays
            case "weekly":
                let days = Set(weekdaysRaw.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
                return .weekly(days)
            case "monthly": return .monthly(day: monthDay)
            case "everyNDays": return .everyNDays(max(1, intervalDays))
            default: return .daily
            }
        }
        set {
            cadenceRaw = newValue.kind
            switch newValue {
            case .weekly(let days):
                weekdaysRaw = days.sorted().map(String.init).joined(separator: ",")
            case .monthly(let day):
                monthDay = min(max(day, 1), 31)
            case .everyNDays(let n):
                intervalDays = max(1, n)
            case .daily, .weekdays:
                break
            }
        }
    }

    var rule: RecurrenceRule {
        RecurrenceRule(cadence: cadence, start: startDate)
    }

    func nextDue(after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        // If today's copy already exists, the next one is tomorrow or later.
        var from = now
        if let last = lastSpawnedDay, calendar.isDate(last, inSameDayAs: now),
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            from = tomorrow
        }
        return rule.nextOccurrence(onOrAfter: from, calendar: calendar)
    }
}

/// Creates today's tasks from routines. Runs at launch and whenever the app comes forward.
@MainActor
enum RoutineStore {
    @discardableResult
    static func spawnDueTasks(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let descriptor = FetchDescriptor<Routine>(predicate: #Predicate { $0.isPaused == false })
        guard let routines = try? context.fetch(descriptor), !routines.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        var created = 0
        for routine in routines {
            let rid: UUID? = routine.uuid
            let openDescriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.routineID == rid && $0.completedAt == nil }
            )
            let hasOpen = ((try? context.fetchCount(openDescriptor)) ?? 0) > 0

            guard RoutineSchedule.shouldSpawn(
                rule: routine.rule,
                isPaused: routine.isPaused,
                lastSpawnedDay: routine.lastSpawnedDay,
                hasOpenTask: hasOpen,
                today: today,
                calendar: calendar
            ) else { continue }

            let index = PlannerLogic.appendIndex(after: TaskStore.openTasks(in: .next, context: context).map(\.sortIndex))
            let task = TaskItem(title: routine.title, slot: .next, sortIndex: index)
            task.estimateMinutes = routine.estimateMinutes
            task.routineID = routine.uuid
            context.insert(task)
            routine.lastSpawnedDay = today
            created += 1
        }
        if created > 0 { TaskStore.save(context) }
        return created
    }

    /// Removes hand-added events that ended more than a day ago.
    static func pruneOldEvents(context: ModelContext, now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        let descriptor = FetchDescriptor<UpcomingEvent>(predicate: #Predicate { $0.date < cutoff })
        guard let old = try? context.fetch(descriptor), !old.isEmpty else { return }
        for event in old { context.delete(event) }
        TaskStore.save(context)
    }

    static func delete(_ routine: Routine, context: ModelContext) {
        context.delete(routine)
        TaskStore.save(context)
    }
}
