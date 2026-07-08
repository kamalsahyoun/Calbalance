import Foundation

/// Bilan calorique pour une période (jour, semaine, mois, année).
struct CalorieBalance: Identifiable {
    var id: Date { periodStart }
    var periodStart: Date
    var caloriesConsumed: Double
    var caloriesBurned: Double
    var target: Double

    /// Positif = surplus (a plus mangé que dépensé), négatif = déficit.
    var balance: Double {
        caloriesConsumed - caloriesBurned
    }

    /// Écart par rapport à l'objectif quotidien (positif = au-dessus de l'objectif).
    var deviationFromTarget: Double {
        caloriesConsumed - target
    }
}

enum AggregationPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "Jour"
        case .week: return "Semaine"
        case .month: return "Mois"
        case .year: return "Année"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

/// Calcule le bilan calorique en combinant les repas (SwiftData) et l'activité (HealthKit).
enum CalorieCalculator {

    /// Découpe [start, end) en sous-intervalles alignés sur `period`, bornes incluses au jour près.
    static func periodBoundaries(from start: Date, to end: Date, period: AggregationPeriod, calendar: Calendar = .current) -> [(start: Date, end: Date)] {
        var boundaries: [(Date, Date)] = []
        var cursor = calendar.dateInterval(of: period.calendarComponent, for: start)?.start ?? start

        while cursor < end {
            guard let next = calendar.date(byAdding: period.calendarComponent, value: 1, to: cursor) else { break }
            boundaries.append((cursor, min(next, end)))
            cursor = next
        }
        return boundaries
    }

    /// Bilan pour un seul jour donné, à partir des repas déjà chargés et d'un résumé d'activité HealthKit.
    static func dailyBalance(date: Date, meals: [Meal], activity: ActivitySummary, target: Double, calendar: Calendar = .current) -> CalorieBalance {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date

        let consumed = meals
            .filter { $0.date >= dayStart && $0.date < dayEnd }
            .reduce(0) { $0 + $1.totalCalories }

        return CalorieBalance(
            periodStart: dayStart,
            caloriesConsumed: consumed,
            caloriesBurned: activity.totalEnergyBurned,
            target: target
        )
    }

    /// Agrège une liste de bilans quotidiens en bilans hebdo/mensuel/annuel (moyennes des cibles, sommes des calories).
    static func aggregate(dailyBalances: [CalorieBalance], into period: AggregationPeriod, calendar: Calendar = .current) -> [CalorieBalance] {
        guard period != .day else { return dailyBalances }

        let grouped = Dictionary(grouping: dailyBalances) { balance in
            calendar.dateInterval(of: period.calendarComponent, for: balance.periodStart)?.start ?? balance.periodStart
        }

        return grouped.map { periodStart, balances in
            CalorieBalance(
                periodStart: periodStart,
                caloriesConsumed: balances.reduce(0) { $0 + $1.caloriesConsumed },
                caloriesBurned: balances.reduce(0) { $0 + $1.caloriesBurned },
                target: balances.reduce(0) { $0 + $1.target }
            )
        }
        .sorted { $0.periodStart < $1.periodStart }
    }
}
