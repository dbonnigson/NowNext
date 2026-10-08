import AppIntents
import Foundation
import SwiftData

/// Marks a task done from the Home Screen widget.
///
/// Conforms to `LiveActivityIntent` so the system runs it in the *app's* process,
/// which keeps the app's on-screen data in sync with the change immediately.
struct CompleteTaskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID) else { return .result() }
        let context = SharedModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == uuid })
        if let task = try context.fetch(descriptor).first, task.completedAt == nil {
            task.completedAt = Date()
            try context.save()
        }
        WidgetRefresher.reload()
        return .result()
    }
}
