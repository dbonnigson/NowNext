import EventKit
import EventKitUI
import SwiftUI

/// An iPhone calendar event opened from Plan.
struct CalendarEventRef: Identifiable {
    let id = UUID()
    let event: EKEvent
    var canEdit: Bool { event.calendar?.allowsContentModifications ?? false }
}

/// Apple's own event editor for calendars NowNext can write to
/// (title, time, calendar, alerts, recurring "this event / future events").
/// Read-only calendars (holidays, subscriptions) get the details screen instead.
struct CalendarEventEditor: UIViewControllerRepresentable {
    let ref: CalendarEventRef
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller: UIViewController
        if ref.canEdit {
            let edit = EKEventEditViewController()
            edit.eventStore = CalendarWriter.eventStore
            edit.event = ref.event
            edit.editViewDelegate = context.coordinator
            controller = edit
        } else {
            let view = EKEventViewController()
            view.event = ref.event
            view.allowsEditing = false
            view.delegate = context.coordinator
            controller = UINavigationController(rootViewController: view)
        }
        controller.overrideUserInterfaceStyle = .dark
        controller.view.tintColor = .white
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate, EKEventViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            onDone()
        }
    }
}
