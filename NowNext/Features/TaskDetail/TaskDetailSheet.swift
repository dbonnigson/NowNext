import SwiftData
import SwiftUI

/// Task details in a bottom sheet: edit, break into tiny steps, guess the time, focus.
struct TaskDetailSheet: View {
    @Bindable var task: TaskItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    @Environment(FocusController.self) private var focus

    @AppStorage(SettingsKey.nowLimit) private var nowLimit = PlannerLogic.defaultNowLimit

    @State private var newStep = ""
    @State private var fullLimit: Int?
    @State private var confirmDelete = false
    @State private var isDeleted = false
    @FocusState private var stepFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: task.isDone ? LocalizedStringKey("Done") : LocalizedStringKey("Task")) { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    fields
                    chips

                    SectionLabel("Where it lives")
                    SlotPicker(selection: slotBinding, disabled: task.isDone)

                    SectionLabel("Tiny steps", trailing: task.stepProgressText.map { _ in
                        "\(task.steps.filter(\.isDone).count)/\(task.steps.count)"
                    })
                    steps

                    SectionLabel("Time guess")
                    EstimatePicker(selection: $task.estimateMinutes)
                    timeStats

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete task", systemImage: "trash")
                    }
                    .buttonStyle(.secondaryDestructive)
                    .padding(.top, Theme.spacingM)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.spacingL)
            }

            BottomActionBar {
                if !task.isDone {
                    Button {
                        router.focus(on: task)
                    } label: {
                        Label(focus.isActive ? LocalizedStringKey("Timer") : LocalizedStringKey("Focus"), systemImage: "timer")
                    }
                    .buttonStyle(.secondary)
                }
                if task.isDone {
                    // Finished tasks are reopened from the list (tap the red check), not here.
                    Button("Close") { dismiss() }
                        .buttonStyle(.secondary)
                } else {
                    Button("Mark done") {
                        // Close the sheet so the task shows up crossed off in the list.
                        TaskStore.setDone(task, true, context: context)
                        dismiss()
                    }
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                }
            }
        }
        .nowFullAlert($fullLimit)
        .sensoryFeedback(.success, trigger: task.isDone)
        .onDisappear {
            if isDeleted {
                // Delete only once the sheet is fully gone, so it never renders a deleted model.
                TaskStore.delete(task, context: context)
                return
            }
            if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                task.title = String(localized: "Untitled task")
            }
            TaskStore.save(context)
        }
        .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                isDeleted = true
                dismiss()
            }
        }
    }

    // MARK: Pieces

    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Task", text: $task.title, axis: .vertical)
                .themeFont(.optionTitle)
                .foregroundStyle(Theme.text)
                .padding(Theme.spacingM)
            Rectangle().fill(Theme.line).frame(height: 1)
            TextField("Notes (optional)", text: $task.notes, axis: .vertical)
                .themeFont(.body)
                .foregroundStyle(Theme.text)
                .lineLimit(2...6)
                .padding(Theme.spacingM)
        }
        .themeCard()
    }

    /// Choices already made, shown as chips.
    private var chips: some View {
        HStack(spacing: 8) {
            Chip(text: task.slot.title, symbol: task.slot.symbol, symbolColor: task.slot.glyphColor)
            if let est = task.estimateMinutes {
                Chip(text: String(localized: "Guess \(DurationText.short(minutes: est))"), symbol: "hourglass")
            }
            if task.trackedSeconds >= 60 {
                Chip(text: String(localized: "Focused \(DurationText.short(seconds: task.trackedSeconds))"), symbol: "timer")
            }
        }
    }

    private var slotBinding: Binding<Slot> {
        Binding(
            get: { task.slot },
            set: { newSlot in
                if case .nowIsFull(let l) = TaskStore.move(task, to: newSlot, nowLimit: nowLimit, context: context) {
                    fullLimit = l
                }
            }
        )
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepsCard
            if task.steps.isEmpty {
                Text("Stuck? Make the first step so small it feels silly, like “open the laptop.”")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var stepsCard: some View {
        VStack(spacing: 0) {
            ForEach(task.orderedSteps) { step in
                HStack(spacing: 12) {
                    PlateCheck(isDone: step.isDone) {
                        withAnimation { TaskStore.toggleStep(step, context: context) }
                    }
                    Text(step.title)
                        .themeFont(.optionTitle)
                        .foregroundStyle(step.isDone ? Theme.muted : Theme.text)
                        .strikethrough(step.isDone, color: Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        withAnimation { TaskStore.deleteStep(step, context: context) }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: Theme.minTap, height: Theme.minTap)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove step \(step.title)")
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 60)
                Rectangle().fill(Theme.line).frame(height: 1)
            }

            HStack(spacing: 12) {
                TextField(task.steps.isEmpty ? LocalizedStringKey("First tiny step…") : LocalizedStringKey("Add a step…"),
                          text: $newStep)
                    .themeFont(.body)
                    .foregroundStyle(Theme.text)
                    .focused($stepFieldFocused)
                    .submitLabel(.next)
                    .onSubmit(addStep)
                Button(action: addStep) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.text)
                        .frame(width: Theme.minTap, height: Theme.minTap)
                        .background(Circle().fill(Theme.red))
                        .overlay(Circle().strokeBorder(Theme.text, lineWidth: Theme.borderSelected))
                }
                .buttonStyle(.plain)
                .disabled(newStep.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newStep.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .accessibilityLabel("Add step")
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 64)
        }
        .themeCard()
    }

    private func addStep() {
        TaskStore.addStep(newStep, to: task, context: context)
        newStep = ""
        stepFieldFocused = true
    }

    @ViewBuilder
    private var timeStats: some View {
        HStack(spacing: 10) {
            StatTile(
                value: task.trackedSeconds > 0 ? DurationText.short(seconds: task.trackedSeconds) : "0m",
                label: String(localized: "Focused so far")
            )
            if let est = task.estimateMinutes, task.trackedSeconds >= 60 {
                let pct = Int((Double(task.trackedSeconds) / Double(est * 60) * 100).rounded())
                StatTile(value: pct.formatted(.percent), label: String(localized: "Of your guess"))
            } else {
                StatTile(value: task.estimateMinutes.map { DurationText.short(minutes: $0) } ?? "–",
                         label: String(localized: "Your guess"))
            }
        }
        .padding(.top, 4)
    }
}
