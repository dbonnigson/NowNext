import SwiftData
import SwiftUI

/// Quick add in a bottom sheet. Respects the Now limit.
struct AddTaskSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.nowLimit) private var nowLimit = PlannerLogic.defaultNowLimit

    @State private var title = ""
    @State private var slot: Slot
    @State private var estimate: Int?
    @State private var fullLimit: Int?
    @FocusState private var titleFocused: Bool

    init(defaultSlot: Slot) {
        _slot = State(initialValue: defaultSlot)
    }

    private var trimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New task") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    TextField("What needs doing?", text: $title, axis: .vertical)
                        .themeFont(.optionTitle)
                        .foregroundStyle(Theme.text)
                        .focused($titleFocused)
                        .padding(Theme.spacingM)
                        .frame(minHeight: 56)
                        .themeCard()

                    SectionLabel("Put it in")
                    SlotPicker(selection: $slot)

                    SectionLabel("Time guess")
                    EstimatePicker(selection: $estimate)
                    Text("A rough guess is fine. NowNext compares it with the time you actually focus.")
                        .themeFont(.detail)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.spacingL)
            }

            BottomActionBar {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.secondary)
                Button("Add task", action: save)
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                    .disabled(trimmed.isEmpty)
            }
        }
        .onAppear { titleFocused = true }
        .nowFullAlert($fullLimit)
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        if slot == .now {
            let count = TaskStore.openTasks(in: .now, context: context).count
            if !PlannerLogic.canAddToNow(currentNowCount: count, limit: nowLimit) {
                fullLimit = PlannerLogic.clampedLimit(nowLimit)
                return
            }
        }
        let created = TaskStore.add([trimmed], to: slot, context: context)
        if let estimate, let task = created.first {
            task.estimateMinutes = estimate
            TaskStore.save(context)
        }
        dismiss()
    }
}

/// 2×2 grid of slot tiles.
struct SlotPicker: View {
    @Binding var selection: Slot
    var disabled = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Slot.allCases) { slot in
                SelectTile(title: slot.title, symbol: slot.symbol, isSelected: selection == slot) {
                    selection = slot
                }
                .disabled(disabled)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Horizontal row of time-guess tiles, including "None".
struct EstimatePicker: View {
    @Binding var selection: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectTile(title: String(localized: "None"), isSelected: selection == nil) {
                    selection = nil
                }
                .frame(width: 76)
                ForEach(EstimateOptions.minutes, id: \.self) { m in
                    SelectTile(title: DurationText.short(minutes: m), isSelected: selection == m) {
                        selection = m
                    }
                    .frame(width: 76)
                }
            }
            .padding(.vertical, 2)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
