import Foundation
import HealthKit
import Observation

/// Résumé des données d'activité HealthKit pour une période donnée.
struct ActivitySummary {
    var activeEnergyBurned: Double = 0   // kcal
    var restingEnergyBurned: Double = 0  // kcal (calories au repos mesurées par l'Apple Watch, quand disponible)
    var steps: Double = 0
    var exerciseMinutes: Double = 0

    /// Dépense totale mesurée par Health pour cette période (actif + repos si dispo).
    var totalEnergyBurned: Double {
        activeEnergyBurned + restingEnergyBurned
    }
}

@Observable
final class HealthKitManager {
    private let healthStore = HKHealthStore()

    private(set) var isAuthorized = false
    private(set) var authorizationError: String?

    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    private let restingEnergyType = HKQuantityType(.basalEnergyBurned)
    private let stepType = HKQuantityType(.stepCount)
    private let exerciseTimeType = HKQuantityType(.appleExerciseTime)
    private let dietaryEnergyType = HKQuantityType(.dietaryEnergyConsumed)

    static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Demande les autorisations de lecture (activité) et d'écriture (calories alimentaires).
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "Apple Health n'est pas disponible sur cet appareil."
            return
        }

        let readTypes: Set<HKObjectType> = [
            activeEnergyType, restingEnergyType, stepType, exerciseTimeType
        ]
        let writeTypes: Set<HKSampleType> = [dietaryEnergyType]

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            authorizationError = nil
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
        }
    }

    // MARK: - Lecture

    /// Récupère le résumé d'activité pour l'intervalle [start, end).
    func fetchActivitySummary(from start: Date, to end: Date) async -> ActivitySummary {
        async let active = sumQuantity(type: activeEnergyType, unit: .kilocalorie(), from: start, to: end)
        async let resting = sumQuantity(type: restingEnergyType, unit: .kilocalorie(), from: start, to: end)
        async let steps = sumQuantity(type: stepType, unit: .count(), from: start, to: end)
        async let exercise = sumQuantity(type: exerciseTimeType, unit: .minute(), from: start, to: end)

        var summary = ActivitySummary()
        summary.activeEnergyBurned = await active
        summary.restingEnergyBurned = await resting
        summary.steps = await steps
        summary.exerciseMinutes = await exercise
        return summary
    }

    private func sumQuantity(type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async -> Double {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Écriture

    /// Écrit les calories consommées d'un repas dans Apple Health.
    /// Retourne l'UUID de l'échantillon créé pour permettre une suppression ultérieure si le repas est édité/supprimé.
    @discardableResult
    func writeDietaryEnergy(calories: Double, date: Date) async throws -> UUID {
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(
            type: dietaryEnergyType,
            quantity: quantity,
            start: date,
            end: date
        )
        try await healthStore.save(sample)
        return sample.uuid
    }

    /// Supprime un échantillon de calories alimentaires précédemment écrit (ex: repas supprimé/modifié).
    func deleteDietaryEnergySample(uuid: UUID) async {
        let predicate = HKQuery.predicateForObject(with: uuid)
        let samples = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: dietaryEnergyType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results ?? [])
                }
            }
            healthStore.execute(query)
        }
        guard let sample = samples?.first else { return }
        try? await healthStore.delete(sample)
    }
}
