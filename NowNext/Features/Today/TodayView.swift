import SwiftData
import SwiftUI

/// Home screen: badge + wordmark, then Now / Next / Later. "Now" is capped (default 3).
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    @Query(filter: #Predicate<TaskItem> { $0.completedAt == nil }, sort: \TaskItem.sortIndex)
    private var openTasks: [TaskItem]

    @Query(filter: #Predicate<TaskItem> { $0.completedAt != nil })
    private var finishedTasks: [TaskItem]

    @AppStorage(SettingsKey.nowLimit) private var nowLimit = PlannerLogic.defaultNowLimit

    @State private var fullLimit: Int?
    @State private var showAdd = false

    private var limit: Int { PlannerLogic.clampedLimit(nowLimit) }

    private func tasks(in slot: Slot) -> [TaskItem] {
        openTasks.filter { $0.slot == slot }
    }

    private var doneToday: [TaskItem] {
        let now = Date()
        return finishedTasks
            .filter { PlannerLogic.isSameDay($0.completedAt, as: now) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var inboxCount: Int { tasks(in: .inbox).count }

    private var isEverythingEmpty: Bool {
        tasks(in: .now).isEmpty && tasks(in: .next).isEmpty && tasks(in: .later).isEmpty && doneToday.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                BrandLockup(badgeSize: 84)
                    .padding(.vertical, 8)
                    .plainListRow()

                if isEverythingEmpty {
                    emptyState
                } else {
                    nowSection
                    slotSection(.next)
                    slotSection(.later)
                    doneSection
                }
            }
            .themedList()
            .animation(.default, value: openTasks.count)
            .themedTabScreen()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomActionBar {
                    Button("Focus") { router.tab = .focus }
                        .buttonStyle(.secondary)
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add task", systemImage: "plus")
                    }
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTaskSheet(defaultSlot: tasks(in: .now).count < limit ? .now : .next)
                    .themedSheet()
            }
            .nowFullAlert($fullLimit)
            .sensoryFeedback(.success, trigger: doneToday.count)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var nowSection: some View {
        let now = tasks(in: .now)
        SectionLabel("Now", trailing: String(localized: "\(now.count) of \(limit)"))
            .plainListRow()

        if now.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nothing in Now yet.")
                    .themeFont(.cardTitle)
                    .foregroundStyle(Theme.text)
                Text("Pick up to \(limit) things from Next or your Brain Dump.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
                if inboxCount > 0 {
                    Button("Open Brain Dump (\(inboxCount))") { router.tab = .brainDump }
                        .buttonStyle(.secondary)
                }
            }
            .padding(.vertical, Theme.spacingM)
            .themedListRow()
        } else {
            ForEach(now) { task in
                row(task)
            }
            .onMove { from, to in
                var items = now
                items.move(fromOffsets: from, toOffset: to)
                TaskStore.reorder(items, context: context)
            }
            if now.count >= limit {
                Callout(title: "Now is full", message: "That's the point. Finish one before adding another.")
                    .plainListRow()
            }
        }
    }

    @ViewBuilder
    private func slotSection(_ slot: Slot) -> some View {
        let items = tasks(in: slot)
        if !items.isEmpty {
            SectionLabel(LocalizedStringKey(slot.title), trailing: "\(items.count)")
                .plainListRow()
            ForEach(items) { task in
                row(task)
            }
            .onMove { from, to in
                var reordered = items
                reordered.move(fromOffsets: from, toOffset: to)
                TaskStore.reorder(reordered, context: context)
            }
        }
    }

    @ViewBuilder
    private var doneSection: some View {
        if !doneToday.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.yellow)
                    .accessibilityHidden(true)
                SectionLabel("Done today", trailing: "\(doneToday.count)")
            }
            .plainListRow()
            ForEach(doneToday) { task in
                TaskRow(task: task) {
                    withAnimation { TaskStore.setDone(task, false, context: context) }
                } onOpen: {
                    router.openTask = task
                }
                .themedListRow()
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        TaskRow(task: task) {
            withAnimation { TaskStore.setDone(task, true, context: context) }
        } onOpen: {
            router.openTask = task
        }
        .themedListRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { TaskStore.setDone(task, true, context: context) }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(Theme.red)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation { TaskStore.delete(task, context: context) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            if task.slot != .now {
                Button {
                    move(task, to: .now)
                } label: {
                    Label("Now", systemImage: Slot.now.symbol)
                }
                .tint(Theme.red)
            } else {
                Button {
                    move(task, to: .next)
                } label: {
                    Label("Next", systemImage: Slot.next.symbol)
                }
                .tint(Theme.surfaceRaised)
            }
        }
        .contextMenu {
            MoveMenuItems(task: task) { move(task, to: $0) }
            Button {
                router.focus(on: task)
            } label: {
                Label("Focus on this", systemImage: "timer")
            }
        }
    }

    private func move(_ task: TaskItem, to slot: Slot) {
        withAnimation {
            if case .nowIsFull(let l) = TaskStore.move(task, to: slot, nowLimit: limit, context: context) {
                fullLimit = l
            }
        }
    }

    // MARK: Empty

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A blank page")
                .themeFont(.cardTitle)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Text("Get everything out of your head first. Then pick just a few things for Now.")
                .themeFont(.body)
                .foregroundStyle(Theme.muted)
            Button {
                router.tab = .brainDump
            } label: {
                Label("Start a Brain Dump", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.primary)
        }
        .padding(.vertical, Theme.spacingM)
        .themedListRow()
    }
}
