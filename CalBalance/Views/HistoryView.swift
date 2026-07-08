import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @Query private var allMeals: [Meal]
    @Query private var profiles: [UserProfile]

    @State private var viewModel: HistoryViewModel

    init() {
        _viewModel = State(initialValue: HistoryViewModel(healthKitManager: HealthKitManager()))
    }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Période", selection: $viewModel.period) {
                        ForEach(AggregationPeriod.allCases.filter { $0 != .day }) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if viewModel.balances.isEmpty {
                        Text("Pas encore de données pour cette période.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        chartSection
                        summarySection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Historique")
            .task(id: viewModel.period) {
                await viewModel.refresh(meals: allMeals, profile: profile)
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Consommé vs dépensé")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(viewModel.balances) { balance in
                    BarMark(
                        x: .value("Période", balance.periodStart, unit: chartUnit),
                        y: .value("Consommé", balance.caloriesConsumed)
                    )
                    .foregroundStyle(.blue)
                    .position(by: .value("Type", "Consommé"))

                    BarMark(
                        x: .value("Période", balance.periodStart, unit: chartUnit),
                        y: .value("Dépensé", balance.caloriesBurned)
                    )
                    .foregroundStyle(.orange)
                    .position(by: .value("Type", "Dépensé"))
                }
            }
            .frame(height: 220)
            .padding(.horizontal)
        }
    }

    private var chartUnit: Calendar.Component {
        switch viewModel.period {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Détail")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.balances.reversed()) { balance in
                HStack {
                    Text(balance.periodStart, format: dateFormat)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(balance.caloriesConsumed)) kcal")
                        .foregroundStyle(.blue)
                    Text("\(Int(balance.caloriesBurned)) kcal")
                        .foregroundStyle(.orange)
                    Text(balance.balance <= 0 ? "-\(Int(abs(balance.balance)))" : "+\(Int(balance.balance))")
                        .font(.subheadline.bold())
                        .foregroundStyle(balance.balance <= 0 ? .green : .red)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
    }

    private var dateFormat: Date.FormatStyle {
        switch viewModel.period {
        case .day: return .dateTime.day().month(.abbreviated)
        case .week: return .dateTime.day().month(.abbreviated)
        case .month: return .dateTime.month(.wide).year()
        case .year: return .dateTime.year()
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Meal.self, UserProfile.self], inMemory: true)
        .environment(HealthKitManager())
}
