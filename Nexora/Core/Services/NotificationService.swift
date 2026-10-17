import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("reminderTime") private var reminderTimeDouble: Double = 8.0 * 3600.0

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        UNUserNotificationCenter.current().delegate = self
        super.init()
        Task {
            await self.refreshAuthorizationStatus()
        }
    }

    var isReminderEnabled: Bool { notificationsEnabled }

    var reminderHour: Int {
        let totalSeconds = Int(reminderTimeDouble)
        return totalSeconds / 3600
    }

    var reminderMinute: Int {
        let totalSeconds = Int(reminderTimeDouble)
        let remainingSeconds = totalSeconds % 3600
        return remainingSeconds / 60
    }

    var reminderTime: Date {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    func refreshAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try? await center.requestAuthorization(options: options)
        await refreshAuthorizationStatus()
        return granted ?? false
    }

    func enableReminders(hour: Int, minute: Int) async {
        let granted = await requestAuthorization()
        guard granted else { return }

        notificationTimeUpdated(hour: hour, minute: minute)
        await scheduleReminder(hour: hour, minute: minute)
        notificationsEnabled = true
    }

    func disableReminders() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        notificationsEnabled = false
    }

    private func notificationTimeUpdated(hour: Int, minute: Int) {
        reminderTimeDouble = Double(hour * 3600 + minute * 60)
    }

    private func scheduleReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["workoutReminder"])

        let content = UNMutableNotificationContent()
        content.title = "Rappel d'entraînement"
        content.body = "Prêt pour votre séance du jour ?"
        content.sound = .default
        content.badge = 1

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let request = UNCalendarNotificationRequest(
            identifier: "workoutReminder",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        try? await center.add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    @objc func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    @objc func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
