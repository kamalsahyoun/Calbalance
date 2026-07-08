import Foundation
import SwiftData
import Observation

@Observable
final class DashboardViewModel {
    private let healthKitManager: HealthKitManager
    private(set) var activitySummary = ActivitySummary()
    private(set) var isLoadingActivity = false

    var selectedDate: Date = .now

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    func refreshActivity() async {
        isLoadingActivity = true
        defer { isLoadingActivity = false }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? selectedDate

        activitySummary = await healthKitManager.fetchActivitySummary(from: start, to: end)
    }

    func balance(meals: [Meal], profile: UserProfile?) -> CalorieBalance {
        let target = profile?.dailyCalorieTarget(activeEnergyFromHealthKit: activitySummary.activeEnergyBurned) ?? 2000
        return CalorieCalculator.dailyBalance(
            date: selectedDate,
            meals: meals,
            activity: activitySummary,
            target: target
        )
    }

    func mealsForSelectedDay(_ allMeals: [Meal]) -> [Meal] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? selectedDate
        return allMeals
            .filter { $0.date >= dayStart && $0.date < dayEnd }
            .sorted { $0.date < $1.date }
    }
}
