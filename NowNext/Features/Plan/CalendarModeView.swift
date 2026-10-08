import SwiftUI

/// Traditional month / week / day calendar, styled to match the rest of the app.
/// Each event still shows how long until it happens.
struct CalendarModeView: View {
    let manualItems: [UpcomingItem]
    var linkedIDs: Set<String> = []
    let onOpen: (UpcomingItem) -> Void
    let onPrep: (UpcomingItem) -> Void
    let onDeleteManual: (UUID) -> Void

    @Environment(CalendarService.self) private var calendarService
    @AppStorage(SettingsKey.calendarScope) private var scopeRaw = CalendarScope.month.rawValue

    @State private var anchor = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var rangeItems: [UpcomingItem] = []

    private var scope: CalendarScope { CalendarScope(rawValue: scopeRaw) ?? .month }
    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            scopePicker
            navigator

            switch scope {
            case .month: monthView
            case .week: weekView
            case .day: DayTimeline(day: anchor, items: CalendarGrid.items(on: anchor, from: rangeItems), onOpen: onOpen, onPrep: onPrep, onDeleteManual: onDeleteManual)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: anchor) { _, _ in reload() }
        .onChange(of: scopeRaw) { _, _ in reload() }
        .onChange(of: calendarService.items) { _, _ in reload() }
        .onChange(of: manualItems) { _, _ in reload() }
    }

    private func reload() {
        let range = CalendarGrid.range(for: scope, anchor: anchor)
        let manual = manualItems.filter { $0.start < range.end && ($0.end ?? $0.start) >= range.start }
        rangeItems = UpcomingTimeline.merge(calendar: calendarService.events(from: range.start, to: range.end), nowNext: manual, linkedIDs: linkedIDs)
    }

    // MARK: Header

    private var scopePicker: some View {
        HStack(spacing: 8) {
            ForEach(CalendarScope.allCases) { s in
                SelectTile(title: s.title, isSelected: scope == s) {
                    scopeRaw = s.rawValue
                    if s == .day { anchor = selectedDay }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: scopeRaw)
    }

    private var navigator: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                roundButton("chevron.left", label: "Previous") { move(-1) }
                Text(title)
                    .themeFont(.cardTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                roundButton("chevron.right", label: "Next") { move(1) }
            }
            if !isShowingToday {
                Button("Back to today") {
                    anchor = Date()
                    selectedDay = calendar.startOfDay(for: Date())
                }
                .font(.system(size: 13, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.red)
                .frame(minHeight: Theme.minTap)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: anchor)
    }

    private var title: String {
        switch scope {
        case .month:
            return anchor.formatted(.dateTime.month(.wide).year())
        case .week:
            let days = CalendarGrid.weekDays(containing: anchor)
            guard let first = days.first, let last = days.last else { return "" }
            return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
        case .day:
            return anchor.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    private var isShowingToday: Bool {
        CalendarGrid.range(for: scope, anchor: anchor).contains(Date())
    }

    private func move(_ value: Int) {
        anchor = CalendarGrid.shift(anchor, by: value, scope: scope)
        if scope == .day { selectedDay = calendar.startOfDay(for: anchor) }
    }

    private func roundButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.text)
                .frame(width: Theme.minTap, height: Theme.minTap)
                .background(Circle().fill(Theme.surfaceRaised))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Month

    private var monthView: some View {
        let days = CalendarGrid.monthGrid(for: anchor)
        let month = calendar.component(.month, from: anchor)
        return VStack(alignment: .leading, spacing: Theme.spacingS) {
            VStack(spacing: 6) {
                weekdayHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        MonthCell(
                            day: day,
                            inMonth: calendar.component(.month, from: day) == month,
                            isToday: calendar.isDateInToday(day),
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                            count: CalendarGrid.items(on: day, from: rangeItems).count
                        ) {
                            // Tap a day to see its events below; tap it again to open Day view.
                            if calendar.isDate(day, inSameDayAs: selectedDay) {
                                anchor = day
                                scopeRaw = CalendarScope.day.rawValue
                            } else {
                                selectedDay = calendar.startOfDay(for: day)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .themeCard()
            .sensoryFeedback(.selection, trigger: selectedDay)

            dayAgenda(selectedDay)
        }
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }
        return HStack(spacing: 4) {
            ForEach(order, id: \.self) { i in
                Text(symbols[i])
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Week

    private var weekView: some View {
        let days = CalendarGrid.weekDays(containing: anchor)
        return VStack(alignment: .leading, spacing: Theme.spacingS) {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    WeekDayChip(
                        day: day,
                        isToday: calendar.isDateInToday(day),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                        count: CalendarGrid.items(on: day, from: rangeItems).count
                    ) {
                        selectedDay = calendar.startOfDay(for: day)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedDay)

            ForEach(days, id: \.self) { day in
                dayAgenda(day, compact: true)
            }
        }
    }

    // MARK: Agenda

    @ViewBuilder
    private func dayAgenda(_ day: Date, compact: Bool = false) -> some View {
        let items = CalendarGrid.items(on: day, from: rangeItems)
        let highlight = compact && calendar.isDate(day, inSameDayAs: selectedDay)
        SectionLabel(
            LocalizedStringKey(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())),
            trailing: items.isEmpty ? String(localized: "free") : "\(items.count)"
        )
        .foregroundStyle(highlight ? Theme.text : Theme.muted)
        if items.isEmpty {
            if !compact {
                Text("Nothing scheduled. Open time.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
                    .padding(Theme.spacingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themeCard()
            }
        } else {
            ForEach(items) { item in
                AgendaRow(item: item, day: day, onOpen: onOpen, onPrep: onPrep, onDeleteManual: onDeleteManual)
            }
        }
    }
}

// MARK: - Cells and rows

private struct MonthCell: View {
    let day: Date
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: isToday || isSelected ? .black : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(inMonth || isSelected ? Theme.text : Theme.gray.opacity(0.6))
                HStack(spacing: 2) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Theme.text : Theme.red)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.red : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected || isToday ? Theme.text : .clear,
                                  lineWidth: isSelected ? Theme.borderSelected : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(day.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(count) events"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct WeekDayChip: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.text : Theme.muted)
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 17, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                Text(count > 0 ? "\(count)" : " ")
                    .font(.system(size: 11, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.text : Theme.red)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .themeCard(selected: isSelected, radius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? Theme.text : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(day.formatted(.dateTime.weekday(.wide).day())), \(count) events"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Time on the left, title + "in 3 days" on the right.
struct AgendaRow: View {
    let item: UpcomingItem
    let day: Date
    let onOpen: (UpcomingItem) -> Void
    let onPrep: (UpcomingItem) -> Void
    let onDeleteManual: (UUID) -> Void

    var body: some View {
        Button { onOpen(item) } label: { content }
            .buttonStyle(.plain)
            .accessibilityHint(Text(UpcomingSection.editLabel(for: item)))
            .contextMenu { UpcomingItemMenu(item: item, onOpen: onOpen, onPrep: onPrep, onDeleteManual: onDeleteManual) }
    }

    private var content: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timeline.date
            let isPast = (item.end ?? item.start) <= now && !(item.isAllDay && Calendar.current.isDateInToday(item.start))
            let c = Countdown.make(start: item.start, end: item.end, isAllDay: item.isAllDay, now: now)

            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(item.isAllDay ? String(localized: "All day") : item.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 14, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(isPast ? Theme.muted : Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 72, height: 48)
                .background(RoundedRectangle(cornerRadius: Theme.radiusIconTile, style: .continuous).fill(Theme.surfaceRaised))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .themeFont(.optionTitle)
                        .foregroundStyle(isPast ? Theme.muted : Theme.text)
                        .lineLimit(2)
                    Text(isPast ? String(localized: "Done") : c.phrase.capitalizedFirst)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isPast ? Theme.muted : (c.isSoon ? Theme.yellow : Theme.red))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 64)
            .themeCard()
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}

/// Long-press menu shared by agenda rows and day-timeline blocks.
struct UpcomingItemMenu: View {
    let item: UpcomingItem
    let onOpen: (UpcomingItem) -> Void
    let onPrep: (UpcomingItem) -> Void
    let onDeleteManual: (UUID) -> Void

    var body: some View {
        if item.taskID == nil {
            Button { onOpen(item) } label: { Label(UpcomingSection.editLabel(for: item), systemImage: "pencil") }
        }
        Button { onPrep(item) } label: { Label(item.taskID == nil ? LocalizedStringKey("Add a prep task") : LocalizedStringKey("Open task"), systemImage: item.taskID == nil ? "checklist" : "arrow.up.forward.square") }
        if case .manual(let id) = item.source {
            Button(role: .destructive) { onDeleteManual(id) } label: { Label("Delete event", systemImage: "trash") }
        }
    }
}

// MARK: - Day timeline

/// Hour grid for one day with event blocks placed by time.
struct DayTimeline: View {
    let day: Date
    let items: [UpcomingItem]
    let onOpen: (UpcomingItem) -> Void
    let onPrep: (UpcomingItem) -> Void
    let onDeleteManual: (UUID) -> Void

    private let hourHeight: CGFloat = 56
    private let labelWidth: CGFloat = 52
    private var calendar: Calendar { .current }

    var body: some View {
        let allDay = items.filter(\.isAllDay)
        let placements = CalendarGrid.dayPlacements(items)
        let bounds = hourBounds(placements)
        let firstHour = bounds.first
        let lastHour = bounds.last

        VStack(alignment: .leading, spacing: Theme.spacingS) {
            if !allDay.isEmpty {
                SectionLabel("All day")
                ForEach(allDay) { item in
                    AgendaRow(item: item, day: day, onOpen: onOpen, onPrep: onPrep, onDeleteManual: onDeleteManual)
                }
            }

            if placements.isEmpty && allDay.isEmpty {
                Text("Nothing scheduled. Open time.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
                    .padding(Theme.spacingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themeCard()
            }

            GeometryReader { geo in
                let columnWidth = geo.size.width - labelWidth - 8
                ZStack(alignment: .topLeading) {
                    // Hour lines and labels
                    ForEach(firstHour...lastHour, id: \.self) { hour in
                        HStack(alignment: .top, spacing: 8) {
                            Text(hourLabel(hour))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.muted)
                                .frame(width: labelWidth, alignment: .trailing)
                                .offset(y: -7)
                            Rectangle()
                                .fill(Theme.line)
                                .frame(height: 1)
                        }
                        .offset(y: CGFloat(hour - firstHour) * hourHeight)
                    }

                    // Events
                    ForEach(placements, id: \.item.id) { p in
                        let top = yOffset(for: max(p.item.start, dayStart), firstHour: firstHour)
                        let end = min(p.item.end ?? p.item.start.addingTimeInterval(30 * 60), dayEnd)
                        let height = max(28, yOffset(for: end, firstHour: firstHour) - top - 2)
                        let width = columnWidth / CGFloat(p.columns)
                        Button { onOpen(p.item) } label: {
                            EventBlock(item: p.item, height: height)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text(UpcomingSection.editLabel(for: p.item)))
                        .frame(width: width - 3, height: height, alignment: .topLeading)
                        .offset(x: labelWidth + 8 + CGFloat(p.column) * width, y: top + 1)
                        .contextMenu { UpcomingItemMenu(item: p.item, onOpen: onOpen, onPrep: onPrep, onDeleteManual: onDeleteManual) }
                    }

                    // Now line
                    if calendar.isDateInToday(day) {
                        TimelineView(.periodic(from: .now, by: 60)) { t in
                            let y = yOffset(for: t.date, firstHour: firstHour)
                            if y >= 0 && y <= CGFloat(lastHour - firstHour) * hourHeight {
                                HStack(spacing: 0) {
                                    Circle().fill(Theme.red).frame(width: 9, height: 9)
                                    Rectangle().fill(Theme.red).frame(height: 2)
                                }
                                .offset(x: labelWidth + 4, y: y - 4.5)
                                .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
            .frame(height: CGFloat(lastHour - firstHour) * hourHeight + 8)
            .padding(.top, 8)
        }
    }

    private var dayStart: Date { calendar.startOfDay(for: day) }
    private var dayEnd: Date { calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart }

    /// Show 7 AM–10 PM, stretched to fit any earlier or later events.
    private func hourBounds(_ placements: [CalendarGrid.Placement]) -> (first: Int, last: Int) {
        var first = 7
        var last = 22
        for p in placements {
            let s = max(p.item.start, dayStart)
            let e = min(p.item.end ?? p.item.start, dayEnd)
            first = min(first, calendar.component(.hour, from: s))
            let endHour = e >= dayEnd ? 24 : calendar.component(.hour, from: e) + 1
            last = max(last, min(endHour, 24))
        }
        return (first: first, last: max(last, first + 1))
    }

    private func yOffset(for date: Date, firstHour: Int) -> CGFloat {
        let minutes = date.timeIntervalSince(dayStart) / 60
        return CGFloat(minutes / 60 - Double(firstHour)) * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour % 24, minute: 0, second: 0, of: dayStart) ?? dayStart
        return hour == 24 ? "" : date.formatted(.dateTime.hour())
    }
}

private struct EventBlock: View {
    let item: UpcomingItem
    let height: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { t in
            let isPast = (item.end ?? item.start) <= t.date
            let c = Countdown.make(start: item.start, end: item.end, isAllDay: false, now: t.date)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .lineLimit(height > 44 ? 2 : 1)
                if height > 40 {
                    Text(isPast ? String(localized: "Done") : c.phrase.capitalizedFirst)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isPast ? Theme.muted : Theme.text.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPast ? Theme.surfaceRaised : Theme.red)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isPast ? Theme.line : Theme.text, lineWidth: 1)
            )
        }
        .accessibilityElement(children: .combine)
    }
}

extension String {
    /// "in 3 days" → "In 3 days".
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
