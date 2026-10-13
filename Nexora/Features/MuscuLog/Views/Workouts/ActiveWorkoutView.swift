import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let workoutTemplate: WorkoutTemplate
    let existingWorkout: CompletedWorkout?

    @State private var completedWorkout: CompletedWorkout?
    @State private var showingCancelAlert = false

    init(workoutTemplate: WorkoutTemplate, existingWorkout: CompletedWorkout? = nil) {
        self.workoutTemplate = workoutTemplate
        self.existingWorkout = existingWorkout
    }

    var body: some View {
        NavigationStack {
            Group {
                if let completedWorkout {
                    List {
                        ForEach(completedWorkout.exercises.sorted(by: { $0.displayOrder < $1.displayOrder })) { exercise in
                            Section {
                                ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                                    ActiveSetRowView(set: set)
                                }
                                Button {
                                    addSet(to: exercise)
                                } label: {
                                    Label("Ajouter une série", systemImage: "plus")
                                }
                            } header: {
                                Text(exercise.exerciseName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                } else {
                    ProgressView("Préparation de la séance…")
                }
            }
            .navigationTitle("En cours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", role: .destructive) {
                        showingCancelAlert = true
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminer") {
                        finishWorkout()
                    }
                    .bold()
                }
            }
            .alert("Annuler la séance ?", isPresented: $showingCancelAlert) {
                Button("Continuer l'entraînement", role: .cancel) { }
                Button("Supprimer et quitter", role: .destructive) {
                    cancelWorkout()
                }
            } message: {
                Text("Toutes les données de cette séance seront perdues.")
            }
            .onAppear {
                startWorkout()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    saveContext()
                }
            }
        }
    }

    @MainActor
    private func getPreviousExercise(name: String) -> CompletedExercise? {
        let descriptor = FetchDescriptor<CompletedWorkout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let allWorkouts = (try? modelContext.fetch(descriptor)) ?? []
        
        for w in allWorkouts {
            if let ex = w.exercises.first(where: { $0.exerciseName == name }) {
                return ex
            }
        }
        return nil
    }

    @MainActor
    private func startWorkout() {
        guard completedWorkout == nil else { return }

        if let existingWorkout {
            completedWorkout = existingWorkout
            return
        }

        let newCompletedWorkout = CompletedWorkout(
            programName: workoutTemplate.program?.name ?? "Sans programme",
            workoutName: workoutTemplate.name
        )
        modelContext.insert(newCompletedWorkout)

        let sortedTemplates = workoutTemplate.exercises.sorted(by: { $0.displayOrder < $1.displayOrder })
        
        for (index, exTemplate) in sortedTemplates.enumerated() {
            let compEx = CompletedExercise(exerciseName: exTemplate.name, displayOrder: index)
            compEx.workout = newCompletedWorkout
            modelContext.insert(compEx)

            let previousEx = getPreviousExercise(name: exTemplate.name)

            for i in 1...exTemplate.targetSets {
                let prevSet = previousEx?.sets.first(where: { $0.setNumber == i })
                let weight = prevSet?.weight ?? 0
                let reps = prevSet?.reps ?? 0
                
                let compSet = CompletedSet(weight: weight, reps: reps, setNumber: i)
                compSet.exercise = compEx
                modelContext.insert(compSet)
            }
        }

        completedWorkout = newCompletedWorkout
        saveContext()
    }

    @MainActor
    private func addSet(to exercise: CompletedExercise) {
        let nextSetNumber = (exercise.sets.map(\.setNumber).max() ?? 0) + 1
        let newSet = CompletedSet(weight: 0, reps: 0, setNumber: nextSetNumber)
        newSet.exercise = exercise
        modelContext.insert(newSet)
        saveContext()
    }

    @MainActor
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Impossible de sauvegarder la séance : \(error.localizedDescription)")
        }
    }

    @MainActor
    private func finishWorkout() {
        completedWorkout?.finishedAt = Date()
        saveContext()
        
        // Vibration de succès native Apple
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        BackupManager.shared.autoBackup(context: modelContext)
        dismiss()
    }

    @MainActor
    private func cancelWorkout() {
        if let completedWorkout {
            modelContext.delete(completedWorkout)
            saveContext()
        }
        dismiss()
    }
}
