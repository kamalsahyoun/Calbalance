import Foundation
import SwiftData

/// Un aliment consommé, rattaché à un `Meal`.
/// Les valeurs nutritionnelles sont stockées pour la quantité réelle consommée
/// (déjà multipliées par `quantityGrams`), pas pour 100g, afin de simplifier
/// les agrégations dans `CalorieCalculator`.
@Model
final class FoodItem {
    var name: String
    var quantityGrams: Double
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    /// Identifiant de l'aliment dans `CommonFoods.json`, nil si détecté uniquement par l'IA
    /// et non rattaché à une entrée de la base locale.
    var databaseFoodId: String?

    var meal: Meal?

    init(
        name: String,
        quantityGrams: Double,
        calories: Double,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        databaseFoodId: String? = nil
    ) {
        self.name = name
        self.quantityGrams = quantityGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.databaseFoodId = databaseFoodId
    }
}

/// Entrée de la base de données locale d'aliments (valeurs pour 100g).
/// Chargée depuis `CommonFoods.json`, pas persistée via SwiftData.
struct FoodDatabaseEntry: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var category: String
}
