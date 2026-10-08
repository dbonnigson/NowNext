import Foundation
import SwiftData

/// All task mutations go through here so views stay thin and rules stay consistent.
@MainActor
enum TaskStore {
    enum MoveResult: Equatable {
        case moved
        case nowIsFull(limit: Int)
    }

    // MARK: Fetch helpers

    static func openTasks(in slot: Slot, context: ModelContext) -> [TaskItem] {
        let raw = slot.rawValue
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.slotRaw == raw && $0.completedAt == nil },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Create

    @discardableResult
    static func addToInbox(_ titles: [String], context: ModelContext) -> [TaskItem] {
        add(titles, to: .inbox, context: context)
    }

    @discardableResult
    static func add(_ titles: [String], to slot: Slot, context: ModelContext) -> [TaskItem] {
        var index = PlannerLogic.appendIndex(after: openTasks(in: slot, context: context).map(\.sortIndex))
        var created: [TaskItem] = []
        for title in titles where !title.isEmpty {
            let task = TaskItem(title: title, slot: slot, sortIndex: index)
            context.insert(task)
            created.append(task)
            index += 1
        }
        save(context)
        return created
    }

    // MARK: Move

    @discardableResult
    static func move(_ task: TaskItem, to slot: Slot, nowLimit: Int, context: ModelContext) -> MoveResult {
        guard task.slot != slot else { return .moved }
        if slot == .now {
            let nowCount = openTasks(in: .now, context: context).count
            if !task.isDone && !PlannerLogic.canAddToNow(currentNowCount: nowCount, limit: nowLimit) {
                return .nowIsFull(limit: PlannerLogic.clampedLimit(nowLimit))
            }
        }
        task.sortIndex = PlannerLogic.appendIndex(after: openTasks(in: slot, context: context).map(\.sortIndex))
        task.slot = slot
        save(context)
        return .moved
    }

    /// Persist a new order after a drag-to-reorder in a list.
    static func reorder(_ tasks: [TaskItem], context: ModelContext) {
        for (i, task) in tasks.enumerated() {
            task.sortIndex = Double(i)
        }
        save(context)
    }

    // MARK: Complete

    static func setDone(_ task: TaskItem, _ done: Bool, context: ModelContext) {
        task.completedAt = done ? Date() : nil
        save(context)
    }

    static func delete(_ task: TaskItem, context: ModelContext) {
        // Also remove the calendar copy NowNext created for it, if any.
        CalendarWriter.remove(eventID: task.calendarEventID)
        context.delete(task)
        save(context)
    }

    // MARK: Steps

    static func addStep(_ title: String, to task: TaskItem, context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let step = TaskStep(title: trimmed, sortIndex: PlannerLogic.appendIndex(after: task.steps.map(\.sortIndex)))
        context.insert(step)
        step.task = task
        save(context)
    }

    static func toggleStep(_ step: TaskStep, context: ModelContext) {
        step.isDone.toggle()
        save(context)
    }

    static func deleteStep(_ step: TaskStep, context: ModelContext) {
        context.delete(step)
        save(context)
    }

    static func reorderSteps(_ steps: [TaskStep], context: ModelContext) {
        for (i, step) in steps.enumerated() {
            step.sortIndex = Double(i)
        }
        save(context)
    }

    // MARK: Focus

    static func recordFocus(
        taskID: UUID?,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        focusedSeconds: Int,
        context: ModelContext
    ) {
        guard focusedSeconds > 0 else { return }
        var task: TaskItem?
        if let taskID {
            let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == taskID })
            task = try? context.fetch(descriptor).first
        }
        let session = FocusSession(
            startedAt: startedAt,
            endedAt: endedAt,
            plannedSeconds: plannedSeconds,
            focusedSeconds: focusedSeconds,
            task: nil
        )
        context.insert(session)
        if let task {
            session.task = task
            task.trackedSeconds += focusedSeconds
        }
        save(context)
    }

    static func task(withID id: UUID, context: ModelContext) -> TaskItem? {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == id })
        return try? context.fetch(descriptor).first
    }

    // MARK: Danger zone

    static func deleteEverything(context: ModelContext) {
        // Delete object-by-object (not a batch delete) so live @Query results
        // are updated instead of left pointing at invalidated models.
        for session in (try? context.fetch(FetchDescriptor<FocusSession>())) ?? [] {
            context.delete(session)
        }
        for task in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] {
            CalendarWriter.remove(eventID: task.calendarEventID)
            context.delete(task) // steps cascade
        }
        for routine in (try? context.fetch(FetchDescriptor<Routine>())) ?? [] {
            context.delete(routine)
        }
        for event in (try? context.fetch(FetchDescriptor<UpcomingEvent>())) ?? [] {
            context.delete(event)
        }
        save(context)
    }

    // MARK: Save

    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("Save failed: \(error)")
        }
        WidgetRefresher.reload()
    }
}
