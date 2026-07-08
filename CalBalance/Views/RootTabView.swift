import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Query private var profiles: [UserProfile]
    @Query private var reminders: [ReminderSetting]

    @State private var hasCheckedOnboarding = false

    var body: some View {
        Group {
            if let profile = profiles.first, profile.hasCompletedOnboarding {
                TabView {
                    DashboardView()
                        .tabItem { Label("Aujourd'hui", systemImage: "flame.fill") }

                    HistoryView()
                        .tabItem { Label("Historique", systemImage: "chart.bar.fill") }

                    ReminderSettingsView()
                        .tabItem { Label("Rappels", systemImage: "bell.fill") }

                    ProfileView()
                        .tabItem { Label("Profil", systemImage: "person.fill") }
                }
            } else {
                OnboardingView {
                    // Le profil vient d'être marqué comme onboardé ; la vue se recompose automatiquement
                    // grâce à @Query, aucune action supplémentaire nécessaire.
                }
            }
        }
        .task {
            guard !hasCheckedOnboarding else { return }
            hasCheckedOnboarding = true
            if healthKitManager.isAuthorized || HealthKitManager.isHealthDataAvailable {
                await healthKitManager.requestAuthorization()
            }
            await notificationManager.refreshAuthorizationStatus()
            notificationManager.rescheduleAll(reminders: reminders)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Meal.self, UserProfile.self, ReminderSetting.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
        .environment(FoodDatabase())
}
