import Foundation

/// UserDefaults keys used with @AppStorage. Keep them in one place.
enum SettingsKey {
    static let hasOnboarded = "hasOnboarded"
    static let nowLimit = "nowLimit"
    static let dailyReminderOn = "dailyReminderOn"
    static let dailyReminderMinutes = "dailyReminderMinutes" // minutes after midnight
    static let isProCached = "isProCached"
    static let focusState = "focusState"
    static let upcomingMode = "upcomingMode"     // "countdown" | "calendar"
    static let calendarScope = "calendarScope"   // "month" | "week" | "day"
    static let scheduleCalendarID = "scheduleCalendarID" // last calendar picked for scheduled tasks
    static let scheduleAddToCalendar = "scheduleAddToCalendar"
}

enum AppLinks {
    // Host these with GitHub Pages from the /docs folder (see README).
    static let privacyPolicy = URL(string: "https://dbonnigson.github.io/NowNext/privacy.html")!
    static let support = URL(string: "https://dbonnigson.github.io/NowNext/")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

enum AppInfo {
    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
