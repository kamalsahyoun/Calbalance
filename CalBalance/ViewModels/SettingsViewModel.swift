import Foundation
import SwiftData
import Observation

@Observable
final class SettingsViewModel {
    private let notificationManager: NotificationManager

    var apiKeyInput: String = ""
    var apiKeySaved: Bool = false

    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        self.apiKeySaved = (KeychainStore.loadAPIKey()?.isEmpty == false)
    }

    func saveAPIKey() {
        guard !apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        KeychainStore.saveAPIKey(apiKeyInput.trimmingCharacters(in: .whitespaces))
        apiKeySaved = true
        apiKeyInput = ""
    }

    func clearAPIKey() {
        KeychainStore.deleteAPIKey()
        apiKeySaved = false
    }

    func addReminder(kind: ReminderKind, time: Date, context: ModelContext) {
        let reminder = ReminderSetting(kind: kind, timeOfDay: time)
        context.insert(reminder)
        notificationManager.schedule(reminder: reminder)
    }

    func updateReminder(_ reminder: ReminderSetting) {
        notificationManager.schedule(reminder: reminder)
    }

    func deleteReminder(_ reminder: ReminderSetting, context: ModelContext) {
        notificationManager.cancel(reminder: reminder)
        context.delete(reminder)
    }

    func toggleReminder(_ reminder: ReminderSetting) {
        reminder.isEnabled.toggle()
        notificationManager.schedule(reminder: reminder)
    }
}
