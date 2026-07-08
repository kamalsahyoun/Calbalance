import SwiftUI
import SwiftData

struct ReminderSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \ReminderSetting.timeOfDay) private var reminders: [ReminderSetting]

    @State private var viewModel: SettingsViewModel
    @State private var showingAddSheet = false
    @State private var newReminderKind: ReminderKind = .eat
    @State private var newReminderTime: Date = .now

    init() {
        _viewModel = State(initialValue: SettingsViewModel(notificationManager: NotificationManager()))
    }

    var body: some View {
        NavigationStack {
            List {
                if !notificationManager.isAuthorized {
                    Section {
                        Button("Autoriser les notifications") {
                            Task { await notificationManager.requestAuthorization() }
                        }
                    } footer: {
                        Text("Les rappels ne fonctionneront pas tant que les notifications ne sont pas autorisées.")
                    }
                }

                Section("Repas") {
                    ForEach(reminders.filter { $0.kind == .eat }) { reminder in
                        ReminderRow(reminder: reminder, viewModel: viewModel)
                    }
                    .onDelete { indexSet in
                        deleteReminders(indexSet, kind: .eat)
                    }
                }

                Section("Hydratation") {
                    ForEach(reminders.filter { $0.kind == .drink }) { reminder in
                        ReminderRow(reminder: reminder, viewModel: viewModel)
                    }
                    .onDelete { indexSet in
                        deleteReminders(indexSet, kind: .drink)
                    }
                }
            }
            .navigationTitle("Rappels")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    Form {
                        Picker("Type", selection: $newReminderKind) {
                            ForEach(ReminderKind.allCases) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        DatePicker("Heure", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                    }
                    .navigationTitle("Nouveau rappel")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annuler") { showingAddSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Ajouter") {
                                viewModel.addReminder(kind: newReminderKind, time: newReminderTime, context: modelContext)
                                showingAddSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task {
                viewModel = SettingsViewModel(notificationManager: notificationManager)
                await notificationManager.refreshAuthorizationStatus()
            }
        }
    }

    private func deleteReminders(_ indexSet: IndexSet, kind: ReminderKind) {
        let filtered = reminders.filter { $0.kind == kind }
        for index in indexSet {
            viewModel.deleteReminder(filtered[index], context: modelContext)
        }
    }
}

private struct ReminderRow: View {
    @Bindable var reminder: ReminderSetting
    let viewModel: SettingsViewModel

    var body: some View {
        HStack {
            Image(systemName: reminder.kind.symbolName)
                .foregroundStyle(reminder.kind == .eat ? .orange : .blue)
            DatePicker("", selection: $reminder.timeOfDay, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .onChange(of: reminder.timeOfDay) {
                    viewModel.updateReminder(reminder)
                }
            Spacer()
            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { _ in viewModel.toggleReminder(reminder) }
            ))
            .labelsHidden()
        }
    }
}

#Preview {
    ReminderSettingsView()
        .modelContainer(for: [ReminderSetting.self], inMemory: true)
        .environment(NotificationManager())
}
