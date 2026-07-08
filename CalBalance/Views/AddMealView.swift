import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(FoodDatabase.self) private var foodDatabase

    @State private var viewModel: AddMealViewModel
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingFoodSearch = false

    init() {
        _viewModel = State(initialValue: AddMealViewModel(
            visionService: FoodVisionService(),
            healthKitManager: HealthKitManager()
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type de repas", selection: $viewModel.category) {
                        ForEach(MealCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                    DatePicker("Heure", selection: $viewModel.date)
                }

                Section("Photo") {
                    if let image = viewModel.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    HStack {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Prendre une photo", systemImage: "camera.fill")
                        }
                        Spacer()
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            Label("Galerie", systemImage: "photo.on.rectangle")
                        }
                    }

                    if viewModel.capturedImage != nil {
                        Button {
                            Task { await viewModel.analyzePhoto() }
                        } label: {
                            if viewModel.isAnalyzing {
                                ProgressView()
                            } else {
                                Label("Analyser avec l'IA", systemImage: "sparkles")
                            }
                        }
                        .disabled(viewModel.isAnalyzing)
                    }

                    if let error = viewModel.analysisError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Aliments (\(Int(viewModel.totalCalories)) kcal)") {
                    ForEach(viewModel.items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.subheadline.bold())
                            Text("\(Int(item.quantityGrams)) g · \(Int(item.calories)) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.removeItem(viewModel.items[index])
                        }
                    }

                    Button {
                        showingFoodSearch = true
                    } label: {
                        Label("Ajouter un aliment manuellement", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Nouveau repas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            _ = await viewModel.saveMeal(context: modelContext)
                            dismiss()
                        }
                    }
                    .disabled(viewModel.items.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView { image in
                    viewModel.capturedImage = image
                }
            }
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchSheet(database: foodDatabase) { entry, grams in
                    viewModel.addFromDatabase(entry, grams: grams, database: foodDatabase)
                }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.capturedImage = image
                    }
                }
            }
            .task {
                viewModel = AddMealViewModel(visionService: FoodVisionService(), healthKitManager: healthKitManager)
            }
        }
    }
}

/// Sheet de recherche/ajout manuel d'un aliment depuis la base locale, avec réglage de la quantité.
private struct FoodSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let database: FoodDatabase
    let onAdd: (FoodDatabaseEntry, Double) -> Void

    @State private var query = ""
    @State private var selectedEntry: FoodDatabaseEntry?
    @State private var grams: Double = 100

    var body: some View {
        NavigationStack {
            VStack {
                if let entry = selectedEntry {
                    VStack(spacing: 16) {
                        Text(entry.name).font(.title3.bold())
                        Stepper("Quantité : \(Int(grams)) g", value: $grams, in: 10...1000, step: 10)
                        let nutrition = database.scaledNutrition(for: entry, grams: grams)
                        Text("\(Int(nutrition.calories)) kcal")
                            .font(.largeTitle.bold())
                        Button("Ajouter au repas") {
                            onAdd(entry, grams)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Choisir un autre aliment") {
                            selectedEntry = nil
                        }
                    }
                    .padding()
                } else {
                    List(database.search(query)) { entry in
                        Button {
                            selectedEntry = entry
                            grams = 100
                        } label: {
                            VStack(alignment: .leading) {
                                Text(entry.name)
                                Text("\(Int(entry.caloriesPer100g)) kcal / 100g")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .searchable(text: $query, prompt: "Rechercher un aliment")
                }
            }
            .navigationTitle("Ajouter un aliment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddMealView()
        .modelContainer(for: [Meal.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(FoodDatabase())
}
