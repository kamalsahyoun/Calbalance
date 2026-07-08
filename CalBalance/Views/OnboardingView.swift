import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(NotificationManager.self) private var notificationManager
    @Query private var profiles: [UserProfile]

    @State private var step = 0
    @State private var isRequestingHealthKit = false
    @State private var isRequestingNotifications = false

    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            switch step {
            case 0: welcomeStep
            case 1: healthKitStep
            default: notificationsStep
            }

            Spacer()

            Button(primaryButtonTitle) {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequestingHealthKit || isRequestingNotifications)
        }
        .padding()
        .multilineTextAlignment(.center)
    }

    private var primaryButtonTitle: String {
        switch step {
        case 0: return "Commencer"
        case 1: return healthKitManager.isAuthorized ? "Continuer" : "Autoriser Apple Health"
        default: return notificationManager.isAuthorized ? "Terminer" : "Autoriser les notifications"
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Bienvenue sur CalBalance")
                .font(.title.bold())
            Text("Suivez vos calories consommées et dépensées au quotidien pour atteindre vos objectifs de poids.")
                .foregroundStyle(.secondary)
        }
    }

    private var healthKitStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Connectez Apple Santé")
                .font(.title.bold())
            Text("CalBalance lira vos calories actives, calories au repos et votre activité pour calculer précisément votre dépense énergétique, et y enregistrera vos calories consommées.")
                .foregroundStyle(.secondary)
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Restez sur la bonne voie")
                .font(.title.bold())
            Text("Activez les notifications pour recevoir des rappels de repas et d'hydratation aux heures que vous choisirez.")
                .foregroundStyle(.secondary)
        }
    }

    private func advance() {
        switch step {
        case 0:
            step = 1
        case 1:
            if healthKitManager.isAuthorized {
                step = 2
            } else {
                isRequestingHealthKit = true
                Task {
                    await healthKitManager.requestAuthorization()
                    isRequestingHealthKit = false
                    step = 2
                }
            }
        default:
            if notificationManager.isAuthorized {
                completeOnboarding()
            } else {
                isRequestingNotifications = true
                Task {
                    await notificationManager.requestAuthorization()
                    isRequestingNotifications = false
                    completeOnboarding()
                }
            }
        }
    }

    private func completeOnboarding() {
        let profile = profiles.first ?? {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            return newProfile
        }()
        profile.hasCompletedOnboarding = true
        onFinished()
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .modelContainer(for: [UserProfile.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
