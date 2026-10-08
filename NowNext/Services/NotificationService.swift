import Foundation
import UserNotifications

/// Local notifications only. Permission is requested in context
/// (first focus session, or turning on the daily reminder), never at launch.
enum NotificationService {
    private static let focusEndID = "focus.end"
    private static let dailyPlanID = "daily.plan"

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func scheduleFocusEnd(at date: Date, taskTitle: String?) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time's up")
        if let taskTitle, !taskTitle.isEmpty {
            content.body = String(localized: "Focus session for “\(taskTitle)” is done. Take a breath.")
        } else {
            content.body = String(localized: "Your focus session is done. Take a breath.")
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: focusEndID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelFocusEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusEndID])
    }

    static func scheduleDailyPlanReminder(minutesAfterMidnight: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Pick your Now")
        content.body = String(localized: "Choose up to three things for today. Just three.")
        content.sound = .default
        var components = DateComponents()
        components.hour = minutesAfterMidnight / 60
        components.minute = minutesAfterMidnight % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyPlanID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelDailyPlanReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyPlanID])
    }
}

/// Shows focus-finished banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
