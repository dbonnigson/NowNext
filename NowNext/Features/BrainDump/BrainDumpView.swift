import SwiftData
import SwiftUI

/// Capture first, sort later. Paste a list and every line becomes a task.
struct BrainDumpView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    @Query(filter: #Predicate<TaskItem> { $0.completedAt == nil && $0.slotRaw == "inbox" }, sort: \TaskItem.sortIndex)
    private var inbox: [TaskItem]

    @AppStorage(SettingsKey.nowLimit) private var nowLimit = PlannerLogic.defaultNowLimit

    @State private var draft = ""
    @State private var fullLimit: Int?
    @State private var justAdded = 0
    @FocusState private var fieldFocused: Bool

    private var parsed: [String] { BrainDumpParser.parse(draft) }

    var body: some View {
        NavigationStack {
            List {
                ScreenTitle("Brain Dump")
                    .padding(.top, 8)
                    .plainListRow()

                captureField
                    .themedListRow()

                Text("Type anything. One thought per line. Don't organize yet.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
                    .plainListRow()

                if inbox.isEmpty {
                    emptyState
                } else {
                    SectionLabel("To sort", trailing: "\(inbox.count)")
                        .plainListRow()
                    ForEach(inbox) { task in
                        row(task)
                    }
                    .onMove { from, to in
                        var items = inbox
                        items.move(fromOffsets: from, toOffset: to)
                        TaskStore.reorder(items, context: context)
                    }
                    Text("Swipe right to send to Now. Swipe left for Next or Later.")
                        .themeFont(.detail)
                        .foregroundStyle(Theme.muted)
                        .plainListRow()
                }
            }
            .themedList()
            .scrollDismissesKeyboard(.interactively)
            .themedTabScreen()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomActionBar {
                    if fieldFocused {
                        Button("Done") { fieldFocused = false }
                            .buttonStyle(.secondary)
                    }
                    Button(action: capture) {
                        Label(parsed.count > 1 ? String(localized: "Capture \(parsed.count)") : String(localized: "Capture"),
                              systemImage: "arrow.down")
                    }
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                    .disabled(parsed.isEmpty)
                }
            }
            .nowFullAlert($fullLimit)
            .sensoryFeedback(.impact(weight: .light), trigger: justAdded)
        }
    }

    private var captureField: some View {
        TextField("What's on your mind?", text: $draft, axis: .vertical)
            .themeFont(.optionTitle)
            .foregroundStyle(Theme.text)
            .lineLimit(3...10)
            .focused($fieldFocused)
            .padding(.vertical, Theme.spacingM)
            .accessibilityLabel("Brain dump")
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            IconTile(symbol: "tray", color: Theme.muted)
            VStack(alignment: .leading, spacing: 3) {
                Text("Your head is clear")
                    .themeFont(.cardTitle)
                    .foregroundStyle(Theme.text)
                Text("Anything you capture waits here until you sort it into Now, Next or Later.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, Theme.spacingM)
        .themedListRow()
    }

    private func capture() {
        let items = parsed
        guard !items.isEmpty else { return }
        withAnimation {
            TaskStore.addToInbox(items, context: context)
        }
        draft = ""
        justAdded += 1
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
                move(task, to: .now)
            } label: {
                Label("Now", systemImage: Slot.now.symbol)
            }
            .tint(Theme.red)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation { TaskStore.delete(task, context: context) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                move(task, to: .later)
            } label: {
                Label("Later", systemImage: Slot.later.symbol)
            }
            .tint(Theme.surfaceRaised)
            Button {
                move(task, to: .next)
            } label: {
                Label("Next", systemImage: Slot.next.symbol)
            }
            .tint(Theme.gray)
        }
        .contextMenu {
            MoveMenuItems(task: task) { move(task, to: $0) }
        }
    }

    private func move(_ task: TaskItem, to slot: Slot) {
        withAnimation {
            if case .nowIsFull(let l) = TaskStore.move(task, to: slot, nowLimit: nowLimit, context: context) {
                fullLimit = l
            }
        }
    }
}
