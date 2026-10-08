import EventKit
import SwiftData
import SwiftUI
import UIKit

/// Upcoming events as "time until", grouped by how far away they are.
struct UpcomingSection: View {
    @Environment(\.modelContext) private var context
    @Environment(CalendarService.self) private var calendarService

    @Query(sort: \UpcomingEvent.date) private var manualEvents: [UpcomingEvent]

    @State private var prepAdded = 0
    @AppStorage(SettingsKey.upcomingMode) private var modeRaw = UpcomingMode.countdown.rawValue

    private var mode: UpcomingMode { UpcomingMode(rawValue: modeRaw) ?? .countdown }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            modeToggle
            calendarAccessCard
            if mode == .countdown {
                countdownView
            } else {
                CalendarModeView(
                    manualItems: manualItems,
                    onPrep: addPrepTask,
                    onDeleteManual: deleteManual
                )
            }
        }
        .sensoryFeedback(.success, trigger: prepAdded)
        .task {
            calendarService.refresh()
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                calendarService.refresh()
            }
        }
    }

    /// Countdown (time-until) vs. traditional calendar.
    private var modeToggle: some View {
        HStack(spacing: 8) {
            ForEach(UpcomingMode.allCases) { m in
                SelectTile(title: m.title, symbol: m.symbol, isSelected: mode == m) {
                    modeRaw = m.rawValue
                }
            }
        }
        .sensoryFeedback(.selection, trigger: modeRaw)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View")
    }

    private var countdownView: some View {
        // Re-render every 30 seconds so countdowns stay live.
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let now = timeline.date
            let items = UpcomingTimeline.upcoming(allItems, now: now)

            VStack(alignment: .leading, spacing: Theme.spacingS) {
                if items.isEmpty {
                    emptyState
                } else {
                    nextUp(items[0], now: now)
                    SectionLabel("Next 14 days")
                    HorizonStrip(counts: UpcomingTimeline.dayCounts(items, days: 14, now: now), now: now)
                    groupedList(Array(items.dropFirst()), now: now)
                }
            }
        }
    }

    private var allItems: [UpcomingItem] {
        calendarService.items + manualItems
    }

    private var manualItems: [UpcomingItem] {
        manualEvents.map {
            UpcomingItem(
                id: "manual-\($0.uuid.uuidString)",
                title: $0.title,
                start: $0.date,
                // Hand-added timed events count as an hour long so they show "Now" while happening.
                end: $0.isAllDay ? nil : $0.date.addingTimeInterval(60 * 60),
                isAllDay: $0.isAllDay,
                source: .manual($0.uuid)
            )
        }
    }

    // MARK: Calendar permission

    @ViewBuilder
    private var calendarAccessCard: some View {
        switch calendarService.access {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconTile(symbol: "calendar", color: Theme.red)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("See your calendar as a countdown")
                            .themeFont(.optionTitle)
                            .foregroundStyle(Theme.text)
                        Text("Read-only. Your events stay on this iPhone.")
                            .themeFont(.detail)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Button("Connect Calendar") {
                    Task { await calendarService.requestAccess() }
                }
                .buttonStyle(.secondary)
            }
            .padding(Theme.spacingM)
            .themeCard()
        case .denied:
            Callout(
                title: "Calendar access is off",
                message: "Turn it on in Settings › NowNext › Calendars to see your events here. You can still add events by hand."
            )
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: url) {
                    Text("Open Settings")
                }
                .buttonStyle(.secondary)
            }
        case .granted:
            EmptyView()
        }
    }

    // MARK: Next up

    private func nextUp(_ item: UpcomingItem, now: Date) -> some View {
        let c = Countdown.make(start: item.start, end: item.end, isAllDay: item.isAllDay, now: now)
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Next up")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(c.value)
                    .themeFont(.wordmark)
                    .foregroundStyle(Theme.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(c.unit)
                    .themeFont(.cardTitle)
                    .foregroundStyle(Theme.text)
            }
            .accessibilityElement(children: .combine)
            Text(item.title)
                .themeFont(.cardTitle)
                .foregroundStyle(Theme.text)
                .lineLimit(3)
                .accessibilityAddTraits(.isHeader)
            Text(detail(for: item, countdown: c))
                .themeFont(.detail)
                .foregroundStyle(Theme.muted)

            if c.isSoon && c.horizon != .now {
                Callout(symbol: "bolt.fill", title: "Starting soon", message: "Wrap up what you're doing and get ready now.")
            }

            Button {
                addPrepTask(for: item)
            } label: {
                Label("Make a prep task", systemImage: "plus")
            }
            .buttonStyle(.secondary)
        }
        .padding(Theme.spacingM)
        .themeCard(radius: Theme.radiusHero)
        .contextMenu { menu(for: item) }
    }

    // MARK: Grouped list

    @ViewBuilder
    private func groupedList(_ items: [UpcomingItem], now: Date) -> some View {
        let groups = Dictionary(grouping: items) {
            Countdown.make(start: $0.start, end: $0.end, isAllDay: $0.isAllDay, now: now).horizon
        }
        ForEach(Countdown.Horizon.allCases, id: \.self) { horizon in
            if let rows = groups[horizon], !rows.isEmpty {
                SectionLabel(LocalizedStringKey(horizon.title), trailing: "\(rows.count)")
                ForEach(rows) { item in
                    row(item, now: now)
                }
            }
        }
    }

    private func row(_ item: UpcomingItem, now: Date) -> some View {
        let c = Countdown.make(start: item.start, end: item.end, isAllDay: item.isAllDay, now: now)
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(c.value)
                    .font(.system(size: Theme.TextStyle.statNumber.scaledSize(), weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(c.isSoon ? Theme.yellow : Theme.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(c.unit)
                    .themeFont(.railLabel)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 78, height: 60)
            .background(RoundedRectangle(cornerRadius: Theme.radiusIconTile, style: .continuous).fill(Theme.surfaceRaised))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .themeFont(.optionTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(detail(for: item, countdown: c))
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: Theme.optionRowMinHeight)
        .themeCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(c.phrase)")
        .contextMenu { menu(for: item) }
    }

    @ViewBuilder
    private func menu(for item: UpcomingItem) -> some View {
        Button {
            addPrepTask(for: item)
        } label: {
            Label("Make a prep task", systemImage: "plus")
        }
        if case .manual(let id) = item.source {
            Button(role: .destructive) {
                deleteManual(id)
            } label: {
                Label("Delete event", systemImage: "trash")
            }
        }
    }

    // MARK: Helpers

    private func detail(for item: UpcomingItem, countdown c: Countdown) -> String {
        var parts: [String] = []
        if c.days > 0 {
            parts.append(item.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        }
        parts.append(item.isAllDay
                     ? String(localized: "All day")
                     : item.start.formatted(date: .omitted, time: .shortened))
        switch item.source {
        case .calendar(let name): parts.append(name)
        case .manual: parts.append(String(localized: "Added in NowNext"))
        }
        return parts.joined(separator: " · ")
    }

    private func deleteManual(_ id: UUID) {
        if let event = manualEvents.first(where: { $0.uuid == id }) {
            context.delete(event)
            TaskStore.save(context)
        }
    }

    private func addPrepTask(for item: UpcomingItem) {
        TaskStore.add([String(localized: "Prep: \(item.title)")], to: .next, context: context)
        prepAdded += 1
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            IconTile(symbol: "hourglass", color: Theme.muted)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nothing coming up")
                    .themeFont(.cardTitle)
                    .foregroundStyle(Theme.text)
                Text("Add an event and NowNext shows how long you have until it, not just the date.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }
}

/// Next 14 days as a rail of bars: busier days are taller and red, so you can
/// *see* how much open time sits between now and the next thing.
struct HorizonStrip: View {
    let counts: [Int]
    let now: Date

    var body: some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let maxCount = max(counts.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                let day = calendar.date(byAdding: .day, value: index, to: calendar.startOfDay(for: now)) ?? now
                let weekday = calendar.component(.weekday, from: day)
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(count > 0 ? Theme.red : Theme.surfaceRaised)
                        .frame(height: count > 0 ? 14 + CGFloat(count) / CGFloat(maxCount) * 22 : 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(index == 0 ? Theme.text : .clear, lineWidth: 1.5)
                        )
                    Text(symbols[weekday - 1])
                        .font(.system(size: 11, weight: index == 0 ? .black : .semibold))
                        .foregroundStyle(index == 0 ? Theme.text : Theme.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60, alignment: .bottom)
        .padding(12)
        .themeCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let busy = counts.filter { $0 > 0 }.count
        return String(localized: "\(busy) of the next 14 days have events")
    }
}
