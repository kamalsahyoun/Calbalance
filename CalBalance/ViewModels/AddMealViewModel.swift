import Foundation
import UIKit
import SwiftData
import Observation

/// Représente une ligne d'aliment en cours d'édition dans l'écran d'ajout de repas,
/// qu'elle vienne de la détection IA ou d'un ajout manuel depuis la base locale.
struct EditableFoodItem: Identifiable {
    var id = UUID()
    var name: String
    var quantityGrams: Double
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var databaseFoodId: String?
}

@Observable
final class AddMealViewModel {
    private let visionService: FoodVisionService
    private let healthKitManager: HealthKitManager

    var category: MealCategory = .lunch
    var date: Date = .now
    var capturedImage: UIImage?
    var items: [EditableFoodItem] = []

    private(set) var isAnalyzing = false
    private(set) var analysisError: String?

    init(visionService: FoodVisionService, healthKitManager: HealthKitManager) {
        self.visionService = visionService
        self.healthKitManager = healthKitManager
    }

    var totalCalories: Double {
        items.reduce(0) { $0 + $1.calories }
    }

    func analyzePhoto() async {
        guard let image = capturedImage else { return }
        isAnalyzing = true
        analysisError = nil
        defer { isAnalyzing = false }

        do {
            let detected = try await visionService.analyzeMealPhoto(image)
            items.append(contentsOf: detected.map {
                EditableFoodItem(
                    name: $0.name,
                    quantityGrams: $0.estimatedQuantityGrams,
                    calories: $0.estimatedCalories,
                    proteinGrams: $0.estimatedProteinGrams,
                    carbsGrams: $0.estimatedCarbsGrams,
                    fatGrams: $0.estimatedFatGrams
                )
            })
        } catch {
            analysisError = error.localizedDescription
        }
    }

    func addFromDatabase(_ entry: FoodDatabaseEntry, grams: Double, database: FoodDatabase) {
        let nutrition = database.scaledNutrition(for: entry, grams: grams)
        items.append(EditableFoodItem(
            name: entry.name,
            quantityGrams: grams,
            calories: nutrition.calories,
            proteinGrams: nutrition.protein,
            carbsGrams: nutrition.carbs,
            fatGrams: nutrition.fat,
            databaseFoodId: entry.id
        ))
    }

    func removeItem(_ item: EditableFoodItem) {
        items.removeAll { $0.id == item.id }
    }

    /// Construit le `Meal` final, l'insère dans le contexte SwiftData fourni,
    /// puis tente de synchroniser les calories consommées vers HealthKit (best-effort, non bloquant).
    func saveMeal(context: ModelContext) async -> Meal {
        let meal = Meal(
            date: date,
            category: category,
            photoData: capturedImage?.jpegData(compressionQuality: 0.6)
        )
        for item in items {
            let foodItem = FoodItem(
                name: item.name,
                quantityGrams: item.quantityGrams,
                calories: item.calories,
                proteinGrams: item.proteinGrams,
                carbsGrams: item.carbsGrams,
                fatGrams: item.fatGrams,
                databaseFoodId: item.databaseFoodId
            )
            meal.foodItems.append(foodItem)
        }
        context.insert(meal)

        if healthKitManager.isAuthorized, meal.totalCalories > 0 {
            if let uuid = try? await healthKitManager.writeDietaryEnergy(calories: meal.totalCalories, date: meal.date) {
                meal.syncedToHealthKit = true
                meal.healthKitSampleUUID = uuid.uuidString
            }
        }

        return meal
    }
}
