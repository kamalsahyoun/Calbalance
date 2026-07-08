import Foundation
import SwiftData

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male, female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Homme"
        case .female: return "Femme"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: return "Sédentaire (peu ou pas d'exercice)"
        case .light: return "Légèrement actif (1-3 jours/semaine)"
        case .moderate: return "Modérément actif (3-5 jours/semaine)"
        case .active: return "Actif (6-7 jours/semaine)"
        case .veryActive: return "Très actif (sport intense quotidien)"
        }
    }

    /// Multiplicateur appliqué au BMR pour obtenir le TDEE (formule Harris-Benedict classique),
    /// utilisé uniquement en secours quand les données HealthKit réelles sont absentes.
    var activityMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum WeightGoal: String, Codable, CaseIterable, Identifiable {
    case lose, maintain, gain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lose: return "Perdre du poids"
        case .maintain: return "Maintenir mon poids"
        case .gain: return "Prendre du poids"
        }
    }

    /// Ajustement quotidien recommandé du budget calorique (déficit/surplus modéré et durable).
    var dailyCalorieAdjustment: Double {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 400
        }
    }
}

@Model
final class UserProfile {
    var birthDate: Date
    var sex: BiologicalSex
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel
    var goal: WeightGoal
    var hasCompletedOnboarding: Bool

    init(
        birthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now,
        sex: BiologicalSex = .male,
        heightCm: Double = 175,
        weightKg: Double = 75,
        activityLevel: ActivityLevel = .moderate,
        goal: WeightGoal = .maintain,
        hasCompletedOnboarding: Bool = false
    ) {
        self.birthDate = birthDate
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
    }

    /// Métabolisme de base (BMR) via la formule de Mifflin-St Jeor,
    /// reconnue comme la plus précise pour la population générale.
    var basalMetabolicRate: Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears))
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// Objectif calorique quotidien = BMR + activité réelle HealthKit (passé en paramètre) + ajustement d'objectif.
    /// Si `activeEnergyFromHealthKit` est nil, on retombe sur l'estimation par multiplicateur d'activité déclaré.
    func dailyCalorieTarget(activeEnergyFromHealthKit: Double?) -> Double {
        let tdee: Double
        if let activeEnergy = activeEnergyFromHealthKit {
            tdee = basalMetabolicRate + activeEnergy
        } else {
            tdee = basalMetabolicRate * activityLevel.activityMultiplier
        }
        return max(1200, tdee + goal.dailyCalorieAdjustment)
    }
}
