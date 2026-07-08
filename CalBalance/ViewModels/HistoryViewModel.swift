import Foundation
import Observation

@Observable
final class HistoryViewModel {
    private let healthKitManager: HealthKitManager

    var period: AggregationPeriod = .week
    private(set) var balances: [CalorieBalance] = []
    private(set) var isLoading = false

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    /// Recharge les bilans pour la période sélectionnée, en remontant sur une fenêtre adaptée
    /// (4 semaines pour la vue semaine, 6 mois pour la vue mois, 3 ans pour la vue année).
    func refresh(meals: [Meal], profile: UserProfile?) async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        let lookback: DateComponents
        switch period {
        case .day: lookback = DateComponents(day: -14)
        case .week: lookback = DateComponents(weekOfYear: -8)
        case .month: lookback = DateComponents(month: -6)
        case .year: lookback = DateComponents(year: -3)
        }
        let start = calendar.date(byAdding: lookback, to: end) ?? end

        // On agrège directement à la granularité demandée (une requête HealthKit par période affichée,
        // pas par jour) pour rester performant même sur des fenêtres d'un an ou plus.
        let boundaries = CalorieCalculator.periodBoundaries(from: start, to: end, period: period, calendar: calendar)

        var results: [CalorieBalance] = []
        for (periodStart, periodEnd) in boundaries {
            let activity = await healthKitManager.fetchActivitySummary(from: periodStart, to: periodEnd)
            let consumed = meals
                .filter { $0.date >= periodStart && $0.date < periodEnd }
                .reduce(0) { $0 + $1.totalCalories }
            let daysInPeriod = max(1, calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 1)
            let dailyTarget = profile?.dailyCalorieTarget(activeEnergyFromHealthKit: activity.activeEnergyBurned / Double(daysInPeriod)) ?? 2000

            results.append(CalorieBalance(
                periodStart: periodStart,
                caloriesConsumed: consumed,
                caloriesBurned: activity.totalEnergyBurned,
                target: dailyTarget * Double(daysInPeriod)
            ))
        }

        balances = results
    }
}
