import SwiftUI
import SwiftData

@main
struct CalBalanceApp: App {
    @State private var healthKitManager = HealthKitManager()
    @State private var notificationManager = NotificationManager()
    @State private var foodDatabase = FoodDatabase()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meal.self,
            FoodItem.self,
            UserProfile.self,
            ReminderSetting.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible de créer le conteneur SwiftData : \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(healthKitManager)
                .environment(notificationManager)
                .environment(foodDatabase)
        }
        .modelContainer(sharedModelContainer)
    }
}
