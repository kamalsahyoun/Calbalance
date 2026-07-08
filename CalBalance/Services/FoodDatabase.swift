import Foundation
import Observation

/// Charge et permet de rechercher dans la base locale d'aliments courants (`CommonFoods.json`).
/// Sert de base pour la confirmation/ajustement manuel après détection photo,
/// et pour l'ajout manuel d'un aliment sans photo.
@Observable
final class FoodDatabase {
    private(set) var entries: [FoodDatabaseEntry] = []

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "CommonFoods", withExtension: "json") else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            entries = try JSONDecoder().decode([FoodDatabaseEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    func search(_ query: String) -> [FoodDatabaseEntry] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return entries }
        let lowerQuery = query.lowercased()
        return entries.filter { $0.name.lowercased().contains(lowerQuery) }
    }

    func entry(withId id: String) -> FoodDatabaseEntry? {
        entries.first { $0.id == id }
    }

    /// Calcule les valeurs nutritionnelles pour une quantité donnée (en grammes) d'une entrée de la base.
    func scaledNutrition(for entry: FoodDatabaseEntry, grams: Double) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let factor = grams / 100.0
        return (
            calories: entry.caloriesPer100g * factor,
            protein: entry.proteinPer100g * factor,
            carbs: entry.carbsPer100g * factor,
            fat: entry.fatPer100g * factor
        )
    }
}
