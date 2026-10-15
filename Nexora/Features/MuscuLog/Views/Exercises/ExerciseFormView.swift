import SwiftUI
import SwiftData

struct ExerciseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var workout: WorkoutTemplate
    var insertAfter: ExerciseTemplate? = nil
    var editingExercise: ExerciseTemplate? = nil

    @State private var name: String = ""
    @State private var targetSets: Int = 3
    @State private var targetReps: String = "8-12"

    let commonReps = ["5", "8", "10", "12", "5-8", "8-10", "8-12", "12-15", "Jusqu'à l'échec"]

    var isEditing: Bool { editingExercise != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de l'exercice", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Exercice")
                } footer: {
                    if let insertAfter {
                        Text("L'exercice sera inséré après : \(insertAfter.name)")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Exemple : Développé couché, Squat…")
                    }
                }

                Section {
                    Stepper(value: $targetSets, in: 1...10) {
                        HStack {
                            Text("Séries prévues")
                            Spacer()
                            Text("\(targetSets)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Volume")
                }

                Section {
                    TextField("Répétitions cibles", text: $targetReps)
                        .autocorrectionDisabled()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(commonReps, id: \.self) { rep in
                                Button {
                                    targetReps = rep
                                } label: {
                                    Text(rep)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundStyle(Color.accentColor)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Objectif de répétitions")
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionText) {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let editingExercise {
                name = editingExercise.name
                targetSets = editingExercise.targetSets
                targetReps = editingExercise.targetReps
            }
        }
    }

    private var titleText: String {
        if isEditing { return "Modifier l'exercice" }
        if insertAfter != nil { return "Insérer un exercice" }
        return "Nouvel exercice"
    }

    private var actionText: String {
        if isEditing { return "Enregistrer" }
        if insertAfter != nil { return "Insérer" }
        return "Ajouter"
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let editingExercise {
            editingExercise.name = trimmedName
            editingExercise.targetSets = targetSets
            editingExercise.targetReps = targetReps
        } else if let insertAfter {
            let newExercise = ExerciseTemplate(
                name: trimmedName,
                targetSets: targetSets,
                targetReps: targetReps,
                displayOrder: insertAfter.displayOrder + 1
            )
            newExercise.workout = workout
            modelContext.insert(newExercise)

            reorderExercises(for: newExercise, after: insertAfter.displayOrder)
        } else {
            let newExercise = ExerciseTemplate(
                name: trimmedName,
                targetSets: targetSets,
                targetReps: targetReps,
                displayOrder: workout.exercises.count
            )
            newExercise.workout = workout
            modelContext.insert(newExercise)
        }

        try? modelContext.save()
        dismiss()
    }

    private func reorderExercises(for newExercise: ExerciseTemplate, after anchorOrder: Int) {
        let exercisesToShift = workout.exercises
            .filter { $0.id != newExercise.id && $0.displayOrder >= newExercise.displayOrder }
            .sorted { $0.displayOrder < $1.displayOrder }

        var newOrder = newExercise.displayOrder + 1
        for exercise in exercisesToShift {
            exercise.displayOrder = newOrder
            newOrder += 1
        }
    }
}
