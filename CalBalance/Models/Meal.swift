import Foundation
import SwiftData

enum MealCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Petit-déjeuner"
        case .lunch: return "Déjeuner"
        case .dinner: return "Dîner"
        case .snack: return "Collation"
        }
    }

    var symbolName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
}

@Model
final class Meal {
    var date: Date
    var category: MealCategory
    /// Photo du repas encodée en JPEG, conservée localement pour référence visuelle.
    var photoData: Data?
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.meal)
    var foodItems: [FoodItem] = []

    /// Indique si ce repas a déjà été synchronisé (écrit) vers HealthKit,
    /// pour éviter les doublons d'énergie alimentaire.
    var syncedToHealthKit: Bool = false
    var healthKitSampleUUID: String?

    init(
        date: Date = .now,
        category: MealCategory,
        photoData: Data? = nil,
        notes: String? = nil
    ) {
        self.date = date
        self.category = category
        self.photoData = photoData
        self.notes = notes
    }

    var totalCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }

    var totalProtein: Double {
        foodItems.reduce(0) { $0 + $1.proteinGrams }
    }

    var totalCarbs: Double {
        foodItems.reduce(0) { $0 + $1.carbsGrams }
    }

    var totalFat: Double {
        foodItems.reduce(0) { $0 + $1.fatGrams }
    }
}
