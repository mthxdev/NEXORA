import SwiftUI
import SwiftData

struct ExerciseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var workout: WorkoutTemplate

    @State private var name: String = ""
    @State private var targetSets: Int = 3
    @State private var targetReps: String = "8-12"

    let commonReps = ["5", "8", "10", "12", "5-8", "8-10", "8-12", "12-15", "Jusqu'à l'échec"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de l'exercice", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Exercice")
                } footer: {
                    Text("Exemple : Développé couché, Squat…")
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
            .navigationTitle("Nouvel exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let newExercise = ExerciseTemplate(
            name: trimmedName,
            targetSets: targetSets,
            targetReps: targetReps,
            displayOrder: workout.exercises.count
        )
        newExercise.workout = workout
        modelContext.insert(newExercise)
        dismiss()
    }
}
