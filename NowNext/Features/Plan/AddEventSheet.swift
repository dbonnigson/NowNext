import SwiftData
import SwiftUI

/// Add an event by hand, or fix one you already added.
/// Quick-pick chips first, exact date/time second.
struct AddEventSheet: View {
    /// nil = new event. Set = editing that event.
    var event: UpcomingEvent?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var date: Date
    @State private var isAllDay: Bool
    @FocusState private var titleFocused: Bool

    init(event: UpcomingEvent? = nil) {
        self.event = event
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: event?.date ?? AddEventSheet.defaultDate())
        _isAllDay = State(initialValue: event?.isAllDay ?? false)
    }

    private var isEditing: Bool { event != nil }

    /// New events start from now. When fixing one, its old date stays pickable
    /// even if it already passed.
    private var earliestDate: Date {
        guard let event else { return Calendar.current.startOfDay(for: Date()) }
        return min(Calendar.current.startOfDay(for: event.date), Calendar.current.startOfDay(for: Date()))
    }

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private enum Quick: String, CaseIterable, Identifiable {
        case tomorrow, threeDays, nextWeek, twoWeeks
        var id: String { rawValue }
        var title: String {
            switch self {
            case .tomorrow: String(localized: "Tomorrow")
            case .threeDays: String(localized: "In 3 days")
            case .nextWeek: String(localized: "In 1 week")
            case .twoWeeks: String(localized: "In 2 weeks")
            }
        }
        var days: Int {
            switch self {
            case .tomorrow: 1
            case .threeDays: 3
            case .nextWeek: 7
            case .twoWeeks: 14
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isEditing ? "Edit event" : "New event") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    TextField("What's happening?", text: $title, axis: .vertical)
                        .themeFont(.optionTitle)
                        .foregroundStyle(Theme.text)
                        .focused($titleFocused)
                        .padding(Theme.spacingM)
                        .frame(minHeight: 56)
                        .themeCard()

                    SectionLabel("When")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Quick.allCases) { q in
                            SelectTile(title: q.title, isSelected: isQuick(q)) {
                                applyQuick(q)
                            }
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
                            in: earliestDate...,
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

                    Text(previewLine)
                        .themeFont(.detail)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.spacingL)
            }

            BottomActionBar {
                if isEditing {
                    Button("Delete", role: .destructive, action: delete)
                        .buttonStyle(.secondaryDestructive)
                } else {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.secondary)
                }
                Button(isEditing ? "Save" : "Add event", action: save)
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                    .disabled(trimmed.isEmpty)
            }
        }
        .onAppear { if !isEditing { titleFocused = true } }
        .sensoryFeedback(.selection, trigger: date)
    }

    private var previewLine: String {
        let c = Countdown.make(start: eventDate, end: nil, isAllDay: isAllDay, now: Date())
        return String(localized: "That's \(c.phrase).")
    }

    private var eventDate: Date {
        isAllDay ? Calendar.current.startOfDay(for: date) : date
    }

    private func isQuick(_ q: Quick) -> Bool {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? -1
        return days == q.days
    }

    private func applyQuick(_ q: Quick) {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: q.days, to: Date()) ?? Date()
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        if let event {
            event.title = trimmed
            event.date = eventDate
            event.isAllDay = isAllDay
        } else {
            context.insert(UpcomingEvent(title: trimmed, date: eventDate, isAllDay: isAllDay))
        }
        TaskStore.save(context)
        dismiss()
    }

    private func delete() {
        if let event { context.delete(event) }
        TaskStore.save(context)
        dismiss()
    }

    /// Next whole hour, at least 30 minutes from now.
    static func defaultDate() -> Date {
        let cal = Calendar.current
        let soon = Date().addingTimeInterval(30 * 60)
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: soon)
        let hour = cal.date(from: comps) ?? soon
        return cal.date(byAdding: .hour, value: 1, to: hour) ?? soon
    }
}
