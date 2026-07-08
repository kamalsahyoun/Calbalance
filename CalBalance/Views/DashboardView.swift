import SwiftUI
import SwiftData
import UIKit

struct DashboardView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @Query private var allMeals: [Meal]
    @Query private var profiles: [UserProfile]

    @State private var viewModel: DashboardViewModel
    @State private var showingAddMeal = false

    init() {
        _viewModel = State(initialValue: DashboardViewModel(healthKitManager: HealthKitManager()))
    }

    private var profile: UserProfile? { profiles.first }

    private var balance: CalorieBalance {
        viewModel.balance(meals: allMeals, profile: profile)
    }

    private var todaysMeals: [Meal] {
        viewModel.mealsForSelectedDay(allMeals)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BalanceRingView(balance: balance)
                        .padding(.top, 8)

                    StatsRow(balance: balance)

                    MealsListSection(meals: todaysMeals)
                }
                .padding()
            }
            .navigationTitle("Aujourd'hui")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMeal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                AddMealView()
            }
            .task {
                viewModel = DashboardViewModel(healthKitManager: healthKitManager)
                await viewModel.refreshActivity()
            }
            .refreshable {
                await viewModel.refreshActivity()
            }
        }
    }
}

private struct BalanceRingView: View {
    let balance: CalorieBalance

    private var progress: Double {
        guard balance.target > 0 else { return 0 }
        return min(1.2, balance.caloriesConsumed / balance.target)
    }

    private var ringColor: Color {
        if balance.caloriesConsumed > balance.target * 1.05 { return .red }
        if balance.caloriesConsumed > balance.target * 0.9 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)

            VStack(spacing: 4) {
                Text("\(Int(balance.caloriesConsumed))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("/ \(Int(balance.target)) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(balance.balance <= 0 ? "Déficit \(Int(abs(balance.balance))) kcal" : "Surplus \(Int(balance.balance)) kcal")
                    .font(.caption)
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: 220, height: 220)
    }
}

private struct StatsRow: View {
    let balance: CalorieBalance

    var body: some View {
        HStack(spacing: 12) {
            StatCard(title: "Consommé", value: balance.caloriesConsumed, icon: "fork.knife", color: .blue)
            StatCard(title: "Dépensé", value: balance.caloriesBurned, icon: "flame.fill", color: .orange)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(Int(value)) kcal")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MealsListSection: View {
    let meals: [Meal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repas du jour")
                .font(.headline)

            if meals.isEmpty {
                Text("Aucun repas enregistré aujourd'hui. Appuyez sur + pour en ajouter un.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(meals) { meal in
                    MealRow(meal: meal)
                }
            }
        }
    }
}

private struct MealRow: View {
    let meal: Meal

    var body: some View {
        HStack(spacing: 12) {
            if let data = meal.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: meal.category.symbolName)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.category.displayName)
                    .font(.subheadline.bold())
                Text(meal.foodItems.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(Int(meal.totalCalories)) kcal")
                .font(.subheadline.bold())
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Meal.self, UserProfile.self], inMemory: true)
        .environment(HealthKitManager())
}
