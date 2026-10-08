import SwiftData
import SwiftUI

/// Puts a task on the NowNext calendar, and optionally on one of the user's
/// iPhone calendars (iCloud, Google, Outlook…). Opened from "Where it lives".
struct ScheduleTaskSheet: View {
    @Bindable var task: TaskItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.scheduleCalendarID) private var lastCalendarID = ""
    @AppStorage(SettingsKey.scheduleAddToCalendar) private var lastAddToCalendar = true

    @State private var title: String
    @State private var date: Date
    @State private var isAllDay: Bool
    @State private var addToCalendar = false
    @State private var calendarID = ""
    @State private var calendars: [CalendarWriter.CalendarChoice] = []
    @State private var accessDenied = false
    @State private var errorMessage: String?

    init(task: TaskItem) {
        self.task = task
        _title = State(initialValue: task.title)
        _date = State(initialValue: task.scheduledAt ?? ScheduleTaskSheet.defaultDate())
        _isAllDay = State(initialValue: task.scheduledAllDay)
    }

    private enum Quick: String, CaseIterable, Identifiable {
        case later, tomorrow, threeDays, nextWeek
        var id: String { rawValue }
        var title: String {
            switch self {
            case .later: String(localized: "Later today")
            case .tomorrow: String(localized: "Tomorrow")
            case .threeDays: String(localized: "In 3 days")
            case .nextWeek: String(localized: "In 1 week")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: task.isScheduled ? LocalizedStringKey("Reschedule") : LocalizedStringKey("Put on calendar")) { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    // Editable here so a typo or wording fix doesn't need a trip back to the task.
                    TextField("What is it?", text: $title, axis: .vertical)
                        .themeFont(.optionTitle)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1...3)
                        .submitLabel(.done)
                        .padding(Theme.spacingM)
                        .frame(minHeight: 56)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themeCard()
                        .accessibilityLabel("Title")

                    SectionLabel("When")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Quick.allCases) { q in
                            SelectTile(title: q.title, isSelected: false) { apply(q) }
                        }
                    }

                    VStack(spacing: 0) {
                        Toggle(isOn: $isAllDay) {
                            Text("All day")
                                .themeFont(.optionTitle)
                                .foregroundStyle(Theme.text)
                        }
                        .tint(Theme.red)
                        .frame(minHeight: 56)
                        Rectangle().fill(Theme.line).frame(height: 1)
                        DatePicker(
                            selection: $date,
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        ) {
                            Text("Date")
                                .themeFont(.optionTitle)
                                .foregroundStyle(Theme.text)
                        }
                        .frame(minHeight: 56)
                    }
                    .padding(.horizontal, Theme.spacingM)
                    .themeCard()

                    Chip(text: countdownLine, symbol: "hourglass", symbolColor: Theme.red)
                        .padding(.top, 2)

                    SectionLabel("Add to")
                    destinations

                    if let errorMessage {
                        Callout(title: "Couldn't add to calendar", message: "\(errorMessage)")
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.spacingL)
            }

            BottomActionBar {
                if task.isScheduled {
                    Button("Unschedule", action: unschedule)
                        .buttonStyle(.secondary)
                } else {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.secondary)
                }
                Button(task.isScheduled ? "Save" : "Schedule", action: save)
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                    .disabled(trimmedTitle.isEmpty)
            }
        }
        .sensoryFeedback(.selection, trigger: date)
        .onAppear(perform: setUp)
    }

    // MARK: Destinations

    private var destinations: some View {
        VStack(spacing: 10) {
            // NowNext calendar is always included.
            OptionRow(title: String(localized: "NowNext calendar"),
                      detail: String(localized: "Shows in Plan › Upcoming with a countdown"),
                      showsChevron: false) {
                IconTile(symbol: "hourglass", color: Theme.red)
            }
            .overlay(alignment: .trailing) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.text)
                    .accessibilityLabel("Included")
            }
            .padding(.horizontal, 14)
            .themeCard()

            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: addToCalendarBinding) {
                    HStack(spacing: 12) {
                        IconTile(symbol: "calendar", color: Theme.text)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Also add to my calendar")
                                .themeFont(.optionTitle)
                                .foregroundStyle(Theme.text)
                            Text(accessDenied
                                 ? String(localized: "Calendar access is off. Turn it on in Settings › NowNext › Calendars.")
                                 : String(localized: "iCloud, Google, Outlook or any calendar on this iPhone"))
                                .themeFont(.detail)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .tint(Theme.red)
                .frame(minHeight: Theme.optionRowMinHeight)
                .disabled(accessDenied)

                if addToCalendar && !calendars.isEmpty {
                    Rectangle().fill(Theme.line).frame(height: 1)
                    Picker(selection: $calendarID) {
                        ForEach(calendars) { cal in
                            Text("\(cal.title) · \(cal.source)").tag(cal.id)
                        }
                    } label: {
                        Text("Calendar")
                            .themeFont(.optionTitle)
                            .foregroundStyle(Theme.text)
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.text)
                    .frame(minHeight: 56)
                }
            }
            .padding(.horizontal, 14)
            .themeCard()
        }
    }

    private var addToCalendarBinding: Binding<Bool> {
        Binding(
            get: { addToCalendar },
            set: { newValue in
                guard newValue else {
                    addToCalendar = false
                    return
                }
                Task {
                    let granted = await CalendarWriter.requestAccess()
                    accessDenied = !granted
                    addToCalendar = granted
                    if granted { loadCalendars() }
                }
            }
        )
    }

    // MARK: Logic

    private var countdownLine: String {
        let start = isAllDay ? Calendar.current.startOfDay(for: date) : date
        let c = Countdown.make(start: start, end: nil, isAllDay: isAllDay, now: Date())
        return String(localized: "That's \(c.phrase)")
    }

    private func setUp() {
        accessDenied = CalendarWriter.isDenied
        if CalendarWriter.hasAccess {
            loadCalendars()
            // Already on a calendar → keep it there. New → remember last choice.
            if let existing = CalendarWriter.calendarID(forEvent: task.calendarEventID) {
                addToCalendar = true
                calendarID = existing
            } else {
                addToCalendar = task.isScheduled ? false : lastAddToCalendar
            }
        }
    }

    private func loadCalendars() {
        calendars = CalendarWriter.writableCalendars()
        if calendarID.isEmpty || !calendars.contains(where: { $0.id == calendarID }) {
            if calendars.contains(where: { $0.id == lastCalendarID }) {
                calendarID = lastCalendarID
            } else {
                calendarID = CalendarWriter.defaultCalendarID ?? calendars.first?.id ?? ""
            }
        }
    }

    private func apply(_ q: Quick) {
        let cal = Calendar.current
        let now = Date()
        switch q {
        case .later:
            isAllDay = false
            date = ScheduleTaskSheet.defaultDate()
        case .tomorrow:
            date = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: now) ?? now) ?? now
        case .threeDays:
            date = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 3, to: now) ?? now) ?? now
        case .nextWeek:
            date = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 7, to: now) ?? now) ?? now
        }
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        errorMessage = nil
        task.title = trimmedTitle
        task.scheduledAt = isAllDay ? Calendar.current.startOfDay(for: date) : date
        task.scheduledAllDay = isAllDay
        // Scheduling clears it out of the Brain Dump so the dump stays a to-sort pile.
        if task.slot == .inbox {
            TaskStore.move(task, to: .later, nowLimit: PlannerLogic.defaultNowLimit, context: context)
        }

        if addToCalendar {
            do {
                task.calendarEventID = try CalendarWriter.upsert(task: task, calendarID: calendarID.isEmpty ? nil : calendarID)
                lastCalendarID = calendarID
            } catch {
                print("NowNext: calendar save failed: \(error)")
                errorMessage = String(localized: "That calendar didn't accept the event. Pick another calendar, or turn off \"Also add to my calendar\".")
            }
        } else if task.calendarEventID != nil {
            // Turned off: take the copy back out of the iPhone calendar.
            CalendarWriter.remove(eventID: task.calendarEventID)
            task.calendarEventID = nil
        }
        lastAddToCalendar = addToCalendar
        TaskStore.save(context)
        if errorMessage == nil { dismiss() }
    }

    private func unschedule() {
        CalendarWriter.remove(eventID: task.calendarEventID)
        task.calendarEventID = nil
        task.scheduledAt = nil
        task.scheduledAllDay = false
        TaskStore.save(context)
        dismiss()
    }

    /// Next whole hour, at least 30 minutes from now.
    static func defaultDate() -> Date {
        let cal = Calendar.current
        let soon = Date().addingTimeInterval(30 * 60)
        let hour = cal.date(from: cal.dateComponents([.year, .month, .day, .hour], from: soon)) ?? soon
        return cal.date(byAdding: .hour, value: 1, to: hour) ?? soon
    }
}
