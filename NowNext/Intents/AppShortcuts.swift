import AppIntents
import Foundation
import SwiftData

/// "Hey Siri, brain dump in NowNext" → capture without opening the app.
struct AddToBrainDumpIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Brain Dump"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Thought", requestValueDialog: "What should I add?")
    var text: String

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let items = BrainDumpParser.parse(text)
        guard !items.isEmpty else {
            return .result(dialog: "Nothing to add.")
        }
        TaskStore.addToInbox(items, context: SharedModelContainer.shared.mainContext)
        let dialog: IntentDialog = items.count == 1
            ? IntentDialog("Added to your brain dump.")
            : IntentDialog("Added \(items.count) items to your brain dump.")
        return .result(dialog: dialog)
    }
}

struct NowNextShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToBrainDumpIntent(),
            phrases: [
                "Add to my \(.applicationName)",
                "Add something to my \(.applicationName)",
                "Brain dump in \(.applicationName)",
                "\(.applicationName) brain dump",
                "Add to \(.applicationName)",
                "Add a task to \(.applicationName)",
                "Add to my \(.applicationName) brain dump",
                "Capture a thought in \(.applicationName)",
            ],
            shortTitle: "Brain Dump",
            systemImageName: "tray.and.arrow.down"
        )
    }
}
