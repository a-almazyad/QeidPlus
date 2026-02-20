import UserNotifications
import Foundation

@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    @Published var isAuthorized: Bool = false
    @Published var reminderEnabled: Bool = false
    @Published var reminderHour: Int = 21   // default 9 PM
    @Published var reminderMinute: Int = 0

    private let reminderID = "qeid.daily.reminder"
    private let defaults = UserDefaults.standard

    private override init() {
        reminderEnabled = defaults.bool(forKey: "reminderEnabled")
        reminderHour    = defaults.integer(forKey: "reminderHour") == 0
            ? 21 : defaults.integer(forKey: "reminderHour")
        reminderMinute  = defaults.integer(forKey: "reminderMinute")
        super.init()
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
            Task { await MobileBackendManager.shared.handleOptInChange(granted && reminderEnabled) }
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

        defaults.set(true,           forKey: "reminderEnabled")
        defaults.set(reminderHour,   forKey: "reminderHour")
        defaults.set(reminderMinute, forKey: "reminderMinute")
        reminderEnabled = true
    }

    func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
        defaults.set(false, forKey: "reminderEnabled")
        reminderEnabled = false
        Task { await MobileBackendManager.shared.handleOptInChange(false) }
    }

    func toggleReminder() {
        if reminderEnabled {
            cancelReminder()
        } else {
            Task {
                if !isAuthorized { await requestPermission() }
                if isAuthorized  {
                    scheduleReminder()
                    await MobileBackendManager.shared.handleOptInChange(true)
                }
            }
        }
    }

    func updateTime(hour: Int, minute: Int) {
        reminderHour   = hour
        reminderMinute = minute
        if reminderEnabled { scheduleReminder() }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Show notification banners even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handle taps on delivered notifications.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
