import SwiftUI
import SwiftData
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let workoutTemplate: WorkoutTemplate
    let existingWorkout: CompletedWorkout?

    @State private var completedWorkout: CompletedWorkout?
    @State private var showingCancelAlert = false
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseTargetSets = 3
    @State private var insertAfterExercise: CompletedExercise?
    @State private var exerciseToDeleteID: String?
    @State private var exerciseToDeleteName: String = ""
    @State private var exerciseToDeleteSetsCount: Int = 0
    @State private var showingDeleteExerciseAlert = false

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
                                    ActiveSetRowView(
                                        set: set,
                                        onDelete: { deleteSet(set, exerciseID: exercise.id) },
                                        onWeightChange: { updateSetWeight(set, weight: $0) },
                                        onRepsChange: { updateSetReps(set, reps: $0) }
                                    )
                                }
                                Button {
                                    addSet(to: exercise)
                                } label: {
                                    Label("Ajouter une série", systemImage: "plus")
                                }
                                Button {
                                    insertAfterExercise = exercise
                                    showingAddExercise = true
                                } label: {
                                    Label("Ajouter un exercice", systemImage: "plus.square")
                                }
                            } header: {
                                HStack {
                                    Text(exercise.exerciseName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Button {
                                        // Capture needed info BEFORE showing alert
                                        exerciseToDeleteID = exercise.id.uuidString
                                        exerciseToDeleteName = exercise.exerciseName
                                        exerciseToDeleteSetsCount = exercise.sets.count
                                        showingDeleteExerciseAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.plain)
                                }
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
            .alert("Nouvel exercice", isPresented: $showingAddExercise) {
                TextField("Nom de l'exercice", text: $newExerciseName)
                Button("Annuler", role: .cancel) {
                    newExerciseName = ""
                }
                Button("Ajouter") {
                    addExerciseAfterCurrent()
                    newExerciseName = ""
                }
            } message: {
                Text("Entrez le nom du nouvel exercice. Il sera inséré après l'exercice courant.")
            }
            .alert("Supprimer cet exercice ?", isPresented: $showingDeleteExerciseAlert) {
                Button("Annuler", role: .cancel) {
                    exerciseToDeleteID = nil
                    exerciseToDeleteName = ""
                    exerciseToDeleteSetsCount = 0
                }
                Button("Supprimer", role: .destructive) {
                    if let idString = exerciseToDeleteID,
                       let id = UUID(uuidString: idString),
                       let ex = completedWorkout?.exercises.first(where: { $0.id == id }) {
                        deleteExercise(ex)
                    }
                    exerciseToDeleteID = nil
                    exerciseToDeleteName = ""
                    exerciseToDeleteSetsCount = 0
                }
            } message: {
                // Use pre-computed values, no SwiftData object capture
                if !exerciseToDeleteName.isEmpty {
                    let hasSets = exerciseToDeleteSetsCount > 0
                    Text(hasSets
                        ? "L'exercice « \(exerciseToDeleteName) » contient \(exerciseToDeleteSetsCount) série\(exerciseToDeleteSetsCount > 1 ? "s" : ""). La suppression est irréversible."
                        : "L'exercice « \(exerciseToDeleteName) » ne contient pas de séries. Confirmez la suppression.")
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
            .onChange(of: scenePhase) { newPhase in
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
    private func updateSetWeight(_ set: CompletedSet, weight: Double) {
        set.weight = weight
        saveContext()
    }

    @MainActor
    private func updateSetReps(_ set: CompletedSet, reps: Int) {
        set.reps = reps
        saveContext()
    }

    @MainActor
    private func addExerciseAfterCurrent() {
        guard let workout = completedWorkout,
              let afterExercise = insertAfterExercise,
              !newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let sortedExercises = workout.exercises.sorted(by: { $0.displayOrder < $1.displayOrder })
        let newDisplayOrder = afterExercise.displayOrder + 1

        let newExercise = CompletedExercise(
            exerciseName: newExerciseName.trimmingCharacters(in: .whitespaces),
            displayOrder: newDisplayOrder
        )
        newExercise.workout = workout
        modelContext.insert(newExercise)

        for exercise in sortedExercises where exercise.displayOrder >= newDisplayOrder && exercise.id != afterExercise.id {
            exercise.displayOrder += 1
        }

        for i in 1...newExerciseTargetSets {
            let newSet = CompletedSet(weight: 0, reps: 0, setNumber: i)
            newSet.exercise = newExercise
            modelContext.insert(newSet)
        }

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
    private func deleteSet(_ set: CompletedSet, exerciseID: UUID) {
        guard let workout = completedWorkout else { return }
        if let exercise = workout.exercises.first(where: { $0.id == exerciseID }) {
            // Capture les séries à renuméroter AVANT de supprimer (évite d'accéder à une relation SwiftData invalide)
            let setsToRenumber = exercise.sets
                .filter { $0.id != set.id }
                .sorted(by: { $0.setNumber < $1.setNumber })
            
            modelContext.delete(set)
            
            // Renuméroter à partir de la liste capturée
            for (index, s) in setsToRenumber.enumerated() {
                s.setNumber = index + 1
            }
            
            saveContext()
        }
    }

    @MainActor
    private func deleteExercise(_ exercise: CompletedExercise) {
        guard let workout = completedWorkout else { return }
        
        // Supprimer l'exercice (les séries en cascade via @Relationship)
        modelContext.delete(exercise)
        
        // Réorganiser l'ordre des exercices restants
        let sortedExercises = workout.exercises.sorted(by: { $0.displayOrder < $1.displayOrder })
        for (index, ex) in sortedExercises.enumerated() {
            ex.displayOrder = index
        }
        
        saveContext()
    }

    @MainActor
    private func finishWorkout() {
        completedWorkout?.finishedAt = Date()
        saveContext()
        
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
