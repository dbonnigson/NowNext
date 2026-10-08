import SwiftData
import SwiftUI

/// Create or edit a routine.
struct RoutineEditorSheet: View {
    let routine: Routine?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var kind: Kind
    @State private var weekdays: Set<Int>
    @State private var monthDay: Int
    @State private var interval: Int
    @State private var estimate: Int?
    @State private var isPaused: Bool
    @State private var confirmDelete = false
    @State private var isDeleted = false

    enum Kind: String, CaseIterable, Identifiable {
        case daily, weekdays, weekly, monthly, everyNDays
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: String(localized: "Daily")
            case .weekdays: String(localized: "Weekdays")
            case .weekly: String(localized: "Weekly")
            case .monthly: String(localized: "Monthly")
            case .everyNDays: String(localized: "Every few days")
            }
        }
    }

    init(routine: Routine?, initialTitle: String = "") {
        self.routine = routine
        let cal = Calendar.current
        let today = Date()
        _title = State(initialValue: routine?.title ?? initialTitle)
        _estimate = State(initialValue: routine?.estimateMinutes)
        _isPaused = State(initialValue: routine?.isPaused ?? false)

        var kind: Kind = .daily
        var weekdays: Set<Int> = [cal.component(.weekday, from: today)]
        var monthDay = cal.component(.day, from: today)
        var interval = 2
        if let cadence = routine?.cadence {
            switch cadence {
            case .daily: kind = .daily
            case .weekdays: kind = .weekdays
            case .weekly(let days):
                kind = .weekly
                if !days.isEmpty { weekdays = days }
            case .monthly(let day):
                kind = .monthly
                monthDay = day
            case .everyNDays(let n):
                kind = .everyNDays
                interval = n
            }
        }
        _kind = State(initialValue: kind)
        _weekdays = State(initialValue: weekdays)
        _monthDay = State(initialValue: monthDay)
        _interval = State(initialValue: interval)
    }

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var cadence: Cadence {
        switch kind {
        case .daily: .daily
        case .weekdays: .weekdays
        case .weekly: .weekly(weekdays)
        case .monthly: .monthly(day: monthDay)
        case .everyNDays: .everyNDays(interval)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: routine == nil ? LocalizedStringKey("New routine") : LocalizedStringKey("Routine")) { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    TextField("What repeats?", text: $title, axis: .vertical)
                        .themeFont(.optionTitle)
                        .foregroundStyle(Theme.text)
                        .padding(Theme.spacingM)
                        .frame(minHeight: 56)
                        .themeCard()

                    SectionLabel("How often")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Kind.allCases) { k in
                            SelectTile(title: k.title, isSelected: kind == k) { kind = k }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: kind)

                    cadenceDetail

                    Chip(text: nextLine, symbol: "hourglass", symbolColor: Theme.red)
                        .padding(.top, 4)

                    SectionLabel("Time guess")
                    EstimatePicker(selection: $estimate)

                    if routine != nil {
                        Toggle(isOn: $isPaused) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Pause this routine")
                                    .themeFont(.optionTitle)
                                    .foregroundStyle(Theme.text)
                                Text("Nothing new shows up while it's paused.")
                                    .themeFont(.detail)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .tint(Theme.red)
                        .padding(.horizontal, Theme.spacingM)
                        .frame(minHeight: Theme.optionRowMinHeight)
                        .themeCard()
                        .padding(.top, Theme.spacingS)

                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Delete routine", systemImage: "trash")
                        }
                        .buttonStyle(.secondaryDestructive)
                        .padding(.top, Theme.spacingS)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.spacingL)
            }

            BottomActionBar {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.secondary)
                Button(routine == nil ? "Add routine" : "Save", action: save)
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                    .disabled(trimmed.isEmpty || (kind == .weekly && weekdays.isEmpty))
            }
        }
        .onDisappear {
            // Delete only after the sheet is gone so it never renders a deleted model.
            if isDeleted, let routine {
                RoutineStore.delete(routine, context: context)
            }
        }
        .confirmationDialog("Delete this routine?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                isDeleted = true
                dismiss()
            }
        } message: {
            Text("Tasks it already created stay in your list.")
        }
    }

    @ViewBuilder
    private var cadenceDetail: some View {
        switch kind {
        case .weekly:
            SectionLabel("On")
            WeekdayPicker(selection: $weekdays)
        case .monthly:
            SectionLabel("Day of the month")
            NumberStepper(value: $monthDay, range: 1...31, label: String(localized: "Day \(monthDay)"))
        case .everyNDays:
            SectionLabel("Every")
            NumberStepper(value: $interval, range: 2...30, label: String(localized: "\(interval) days"))
        case .daily, .weekdays:
            EmptyView()
        }
    }

    private var nextLine: String {
        if kind == .weekly && weekdays.isEmpty {
            return String(localized: "Pick at least one day")
        }
        let rule = RecurrenceRule(cadence: cadence, start: isDeleted ? Date() : (routine?.startDate ?? Date()))
        guard let next = rule.nextOccurrence(onOrAfter: Date()) else {
            return String(localized: "Pick at least one day")
        }
        let c = Countdown.make(start: next, end: nil, isAllDay: true, now: Date())
        let schedule = RoutineSchedule.describe(cadence)
        return String(localized: "\(schedule) · next one \(c.phrase)")
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        let target: Routine
        if let routine {
            target = routine
        } else {
            target = Routine(title: trimmed, startDate: Calendar.current.startOfDay(for: Date()))
            context.insert(target)
        }
        target.title = trimmed
        target.cadence = cadence
        target.estimateMinutes = estimate
        target.isPaused = isPaused
        TaskStore.save(context)
        // If it's due today, it appears in Next right away.
        RoutineStore.spawnDueTasks(context: context)
        dismiss()
    }
}

/// Seven toggle tiles, in the user's locale order.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                SelectTile(title: symbols[day - 1], isSelected: selection.contains(day)) {
                    if selection.contains(day) {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                }
                .accessibilityLabel(cal.weekdaySymbols[day - 1])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Minus / value / plus row with 48pt round buttons.
struct NumberStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            round("minus", a11y: "Less") { value = max(range.lowerBound, value - 1) }
            Text(label)
                .themeFont(.statNumber)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
            round("plus", a11y: "More") { value = min(range.upperBound, value + 1) }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: value)
    }

    private func round(_ symbol: String, a11y: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.text)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.surfaceRaised))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }
}
