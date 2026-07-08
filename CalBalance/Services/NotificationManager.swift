import Foundation
import UserNotifications
import Observation

@Observable
final class NotificationManager {
    private let center = UNUserNotificationCenter.current()

    private(set) var isAuthorized = false

    private static func identifier(for reminder: ReminderSetting) -> String {
        "reminder-\(reminder.id.uuidString)"
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    /// Planifie (ou reprogramme) une notification quotidienne récurrente pour ce rappel.
    func schedule(reminder: ReminderSetting) {
        let id = Self.identifier(for: reminder)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard reminder.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.kind.notificationTitle
        content.body = reminder.customLabel?.isEmpty == false ? reminder.customLabel! : reminder.kind.notificationBody
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    func cancel(reminder: ReminderSetting) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: reminder)])
    }

    /// Reprogramme l'ensemble des rappels actifs, utile au lancement de l'app pour garantir la cohérence
    /// entre l'état stocké (SwiftData) et les notifications planifiées côté système.
    func rescheduleAll(reminders: [ReminderSetting]) {
        center.removeAllPendingNotificationRequests()
        for reminder in reminders where reminder.isEnabled {
            schedule(reminder: reminder)
        }
    }
}
