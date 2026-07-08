import Foundation
import SwiftData

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case eat, drink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eat: return "Repas"
        case .drink: return "Hydratation"
        }
    }

    var notificationTitle: String {
        switch self {
        case .eat: return "🍽️ C'est l'heure de manger"
        case .drink: return "💧 Pensez à boire de l'eau"
        }
    }

    var notificationBody: String {
        switch self {
        case .eat: return "N'oubliez pas de prendre un repas équilibré et de le noter dans CalBalance."
        case .drink: return "Restez hydraté ! Prenez un verre d'eau."
        }
    }

    var symbolName: String {
        switch self {
        case .eat: return "fork.knife"
        case .drink: return "drop.fill"
        }
    }
}

/// Un rappel récurrent quotidien à une heure donnée (manger ou boire).
/// Chaque rappel est planifié individuellement dans `UNUserNotificationCenter`
/// via un identifiant stable (`id.uuidString`) pour pouvoir être mis à jour/annulé.
@Model
final class ReminderSetting {
    var id: UUID
    var kind: ReminderKind
    /// Heure et minute du rappel (la date elle-même est ignorée, seuls hour/minute comptent).
    var timeOfDay: Date
    var isEnabled: Bool
    var customLabel: String?

    init(
        id: UUID = UUID(),
        kind: ReminderKind,
        timeOfDay: Date,
        isEnabled: Bool = true,
        customLabel: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.timeOfDay = timeOfDay
        self.isEnabled = isEnabled
        self.customLabel = customLabel
    }

    var hour: Int {
        Calendar.current.component(.hour, from: timeOfDay)
    }

    var minute: Int {
        Calendar.current.component(.minute, from: timeOfDay)
    }
}
