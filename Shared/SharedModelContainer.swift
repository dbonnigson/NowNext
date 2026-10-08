import Foundation
import SwiftData
import WidgetKit

enum AppGroup {
    static let identifier = "group.ai.palmettogroup.nownext"
}

/// One SwiftData store shared by the app, its widgets and App Intents.
/// Lives in the App Group container so the widget extension can read it.
enum SharedModelContainer {
    static let schema = Schema([TaskItem.self, TaskStep.self, FocusSession.self, Routine.self, UpcomingEvent.self])

    static let shared: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        // 1. Preferred: App Group store (shared with widgets).
        let grouped = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [grouped])
        } catch {
            // Visible in Xcode's console. If you ever see this after a schema change,
            // add a VersionedSchema + SchemaMigrationPlan before shipping.
            print("NowNext: App Group store failed to open: \(error)")
        }

        // 2. Fallback: app-private store (e.g. App Group not provisioned yet).
        let local = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: [local]) {
            return container
        }

        // 3. Last resort so the app still launches instead of crashing.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [memory])
        } catch {
            fatalError("Unable to create any SwiftData container: \(error)")
        }
    }

    /// In-memory container for previews and tests.
    static func inMemory() -> ModelContainer {
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [memory])
        } catch {
            fatalError("Unable to create in-memory container: \(error)")
        }
    }
}

enum WidgetRefresher {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
