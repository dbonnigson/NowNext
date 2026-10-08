import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: Timeline

struct NowEntry: TimelineEntry {
    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
    }

    let date: Date
    let items: [Item]
    let doneToday: Int
}

struct NowProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowEntry {
        NowEntry(
            date: Date(),
            items: [
                .init(id: "1", title: String(localized: "Reply to that email")),
                .init(id: "2", title: String(localized: "Start the report")),
            ],
            doneToday: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowEntry>) -> Void) {
        let entry = loadEntry()
        // The app reloads timelines whenever tasks change; this is just a safety refresh
        // (and rolls the "done today" count over at midnight).
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date().addingTimeInterval(3600)
        let refresh = min(midnight, Date().addingTimeInterval(60 * 60))
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> NowEntry {
        let context = ModelContext(SharedModelContainer.shared)
        let nowRaw = "now"
        let open = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.slotRaw == nowRaw && $0.completedAt == nil },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        let tasks = (try? context.fetch(open)) ?? []

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let done = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.completedAt != nil })
        let doneToday = ((try? context.fetch(done)) ?? []).filter { ($0.completedAt ?? .distantPast) >= startOfDay }.count

        return NowEntry(
            date: Date(),
            items: tasks.map { .init(id: $0.uuid.uuidString, title: $0.title) },
            doneToday: doneToday
        )
    }
}

// MARK: Views

struct NowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NowEntry

    private var visibleCount: Int {
        switch family {
        case .systemSmall: 2
        case .accessoryRectangular: 2
        default: 3
        }
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessory
        default:
            system
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Theme.yellow)
                .accessibilityHidden(true)
            Text("Now")
                .font(.system(size: 17, weight: .black))
                .textCase(.uppercase)
                .foregroundStyle(Theme.red)
            Spacer()
            if entry.doneToday > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                    Text("\(entry.doneToday)")
                        .monospacedDigit()
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.muted)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.doneToday) done today")
            }
        }
    }

    private var system: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if entry.items.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing in Now")
                    .font(.system(size: 15, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.text)
                Text("Open NowNext and pick up to three.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.items.prefix(visibleCount)) { item in
                    HStack(spacing: 8) {
                        Button(intent: CompleteTaskIntent(taskID: item.id)) {
                            Circle()
                                .strokeBorder(Theme.text, lineWidth: 2)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mark \(item.title) done")
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
                if entry.items.count > visibleCount {
                    Text("+\(entry.items.count - visibleCount) more")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Now", systemImage: "bolt.fill")
                .font(.headline)
            if entry.items.isEmpty {
                Text("Pick up to three")
                    .font(.caption)
            } else {
                ForEach(entry.items.prefix(visibleCount)) { item in
                    Text(item.title)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NowWidget: Widget {
    let kind = "NowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowProvider()) { entry in
            NowWidgetView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
                .environment(\.colorScheme, .dark)
        }
        .configurationDisplayName("Now")
        .description("Your Now list, with a tap to check things off.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
