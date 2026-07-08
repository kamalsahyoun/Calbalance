import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Query private var profiles: [UserProfile]

    @State private var settingsViewModel: SettingsViewModel

    init() {
        _settingsViewModel = State(initialValue: SettingsViewModel(notificationManager: NotificationManager()))
    }

    // `RootTabView` garantit qu'un `UserProfile` existe déjà (créé pendant l'onboarding)
    // avant que cet écran ne soit affiché ; ce placeholder ne sert que pour les previews/edge cases
    // et n'est jamais inséré dans le contexte pour éviter les doublons.
    private var profile: UserProfile {
        profiles.first ?? UserProfile()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations personnelles") {
                    DatePicker("Date de naissance", selection: Binding(
                        get: { profile.birthDate },
                        set: { profile.birthDate = $0 }
                    ), displayedComponents: .date)

                    Picker("Sexe biologique", selection: Binding(
                        get: { profile.sex },
                        set: { profile.sex = $0 }
                    )) {
                        ForEach(BiologicalSex.allCases) { sex in
                            Text(sex.displayName).tag(sex)
                        }
                    }

                    HStack {
                        Text("Taille")
                        Spacer()
                        TextField("cm", value: Binding(
                            get: { profile.heightCm },
                            set: { profile.heightCm = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        Text("cm")
                    }

                    HStack {
                        Text("Poids")
                        Spacer()
                        TextField("kg", value: Binding(
                            get: { profile.weightKg },
                            set: { profile.weightKg = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        Text("kg")
                    }
                }

                Section("Activité et objectif") {
                    Picker("Niveau d'activité", selection: Binding(
                        get: { profile.activityLevel },
                        set: { profile.activityLevel = $0 }
                    )) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }

                    Picker("Objectif", selection: Binding(
                        get: { profile.goal },
                        set: { profile.goal = $0 }
                    )) {
                        ForEach(WeightGoal.allCases) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Métabolisme de base (BMR)")
                        Spacer()
                        Text("\(Int(profile.basalMetabolicRate)) kcal")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Objectif calorique estimé")
                        Spacer()
                        Text("\(Int(profile.dailyCalorieTarget(activeEnergyFromHealthKit: nil))) kcal")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("L'objectif réel affiché sur le tableau de bord tient compte de votre activité mesurée par Apple Health.")
                }

                Section("Clé API Claude (analyse photo)") {
                    if settingsViewModel.apiKeySaved {
                        HStack {
                            Label("Clé API configurée", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Supprimer", role: .destructive) {
                                settingsViewModel.clearAPIKey()
                            }
                        }
                    } else {
                        SecureField("Clé API (sk-ant-...)", text: $settingsViewModel.apiKeyInput)
                        Button("Enregistrer la clé") {
                            settingsViewModel.saveAPIKey()
                        }
                        .disabled(settingsViewModel.apiKeyInput.isEmpty)
                    }
                } footer: {
                    Text("Nécessaire pour l'analyse automatique des photos de repas. Obtenez une clé sur console.anthropic.com. Elle est stockée uniquement sur cet appareil (Keychain).")
                }
            }
            .navigationTitle("Profil")
            .task {
                settingsViewModel = SettingsViewModel(notificationManager: notificationManager)
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
        .environment(NotificationManager())
}
