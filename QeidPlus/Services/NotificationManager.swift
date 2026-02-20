import UserNotifications
import Foundation

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var isAuthorized: Bool = false
    @Published var reminderEnabled: Bool = false
    @Published var reminderHour: Int = 21   // default 9 PM
    @Published var reminderMinute: Int = 0

    private let reminderID = "qeid.daily.reminder"
    private let defaults = UserDefaults.standard

    private init() {
        reminderEnabled = defaults.bool(forKey: "reminderEnabled")
        reminderHour    = defaults.integer(forKey: "reminderHour") == 0
            ? 21 : defaults.integer(forKey: "reminderHour")
        reminderMinute  = defaults.integer(forKey: "reminderMinute")
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Authorization

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted && reminderEnabled {
                scheduleReminder()
            }
        } catch {
            isAuthorized = false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        var components = DateComponents()
        components.hour   = reminderHour
        components.minute = reminderMinute

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_title", comment: "")
        content.body  = NSLocalizedString("notification_body",  comment: "")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)

        defaults.set(true,          forKey: "reminderEnabled")
        defaults.set(reminderHour,  forKey: "reminderHour")
        defaults.set(reminderMinute, forKey: "reminderMinute")
        reminderEnabled = true
    }

    func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
        defaults.set(false, forKey: "reminderEnabled")
        reminderEnabled = false
    }

    func toggleReminder() {
        if reminderEnabled {
            cancelReminder()
        } else {
            Task {
                if !isAuthorized { await requestPermission() }
                if isAuthorized  { scheduleReminder() }
            }
        }
    }

    func updateTime(hour: Int, minute: Int) {
        reminderHour   = hour
        reminderMinute = minute
        if reminderEnabled { scheduleReminder() }
    }
}
