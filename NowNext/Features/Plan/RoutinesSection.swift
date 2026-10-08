import SwiftData
import SwiftUI

/// Recurring tasks. Each day a routine is due, one copy lands in Next.
struct RoutinesSection: View {
    @Query(sort: \Routine.createdAt) private var routines: [Routine]

    @State private var editing: Routine?
    @State private var suggestion: String?

    private let suggestions = [
        String(localized: "Empty the dishwasher"),
        String(localized: "Check the mail"),
        String(localized: "Pay bills"),
        String(localized: "Weekly review"),
        String(localized: "Water the plants"),
        String(localized: "Take out the trash"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Callout(
                symbol: "repeat",
                title: "How routines work",
                message: "On the day a routine is due, it shows up in Next. Miss a day? It doesn't pile up. You get one copy, never a stack."
            )

            if routines.isEmpty {
                SectionLabel("Try one")
                FlowChips(items: suggestions) { suggestion = $0 }
            } else {
                SectionLabel("Your routines", trailing: "\(routines.count)")
                ForEach(routines) { routine in
                    Button {
                        editing = routine
                    } label: {
                        OptionRow(title: routine.title, detail: detail(for: routine)) {
                            IconTile(symbol: routine.isPaused ? "pause.fill" : "repeat",
                                     color: routine.isPaused ? Theme.muted : Theme.red)
                        }
                        .padding(.horizontal, 14)
                        .themeCard()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit routine")
                }
            }
        }
        .sheet(item: $editing) { routine in
            RoutineEditorSheet(routine: routine)
                .themedSheet()
        }
        .sheet(item: Binding(
            get: { suggestion.map { SuggestionID(title: $0) } },
            set: { suggestion = $0?.title }
        )) { s in
            RoutineEditorSheet(routine: nil, initialTitle: s.title)
                .themedSheet()
        }
    }

    private struct SuggestionID: Identifiable {
        let title: String
        var id: String { title }
    }

    private func detail(for routine: Routine) -> String {
        let schedule = RoutineSchedule.describe(routine.cadence)
        if routine.isPaused {
            return String(localized: "\(schedule) · Paused")
        }
        guard let next = routine.nextDue() else { return schedule }
        let c = Countdown.make(start: next, end: nil, isAllDay: true, now: Date())
        let when = c.days == 0 ? String(localized: "due today") : String(localized: "next \(c.phrase)")
        return "\(schedule) · \(when)"
    }
}

/// Wrapping row of tappable suggestion chips.
struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Button { onTap(item) } label: {
                            Chip(text: item, symbol: "plus", symbolColor: Theme.red)
                                .frame(minHeight: Theme.minTap)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Simple two-per-row layout keeps chips readable at large text sizes.
    private var rows: [[String]] {
        stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
    }
}
