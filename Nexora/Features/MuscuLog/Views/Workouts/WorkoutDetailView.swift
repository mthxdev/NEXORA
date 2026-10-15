import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: WorkoutTemplate

    @State private var showingAddExercise = false
    @State private var showingActiveWorkout = false
    @State private var showingEditName = false
    @State private var insertAfterExercise: ExerciseTemplate?
    @State private var editingExercise: ExerciseTemplate?
    @State private var newName = ""

    var sortedExercises: [ExerciseTemplate] {
        workout.exercises.sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        List {
            if sortedExercises.isEmpty {
                Text("Aucun exercice prévu.\nAjoute-en un pour commencer !")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(sortedExercises) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline)
                        HStack {
                            Text("\(exercise.targetSets) séries")
                            Text("•")
                            Text("\(exercise.targetReps) reps")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, style: .destructive) {
                        Button("Supprimer", systemImage: "trash") {
                            deleteExercise(exercise)
                        }
                    }
                    .contextMenu {
                        Button("Insérer après", systemImage: "plus.badge.arrow.down") {
                            insertAfterExercise = exercise
                        }
                        Button("Modifier", systemImage: "pencil") {
                            editingExercise = exercise
                        }
                        Button("Supprimer", systemImage: "trash", role: .destructive) {
                            deleteExercise(exercise)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)
            }
        }
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("Ajouter un exercice", systemImage: "plus")
                    }
                    Button {
                        editingExercise = sortedExercises.first
                    } label: {
                        Label("Modifier un exercice", systemImage: "pencil")
                    }
                    Button {
                        showingEditName = true
                    } label: {
                        Label("Renommer la séance", systemImage: "pencil.line.wrench")
                    }
                    Button {
                        startSession()
                    } label: {
                        Label("Démarrer la séance", systemImage: "play.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if sortedExercises.count > 1 {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            ExerciseFormView(workout: workout)
        }
        .sheet(item: $insertAfterExercise) { exercise in
            ExerciseFormView(workout: workout, insertAfter: exercise)
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseFormView(workout: workout, editingExercise: exercise)
        }
        .alert("Renommer la séance", isPresented: $showingEditName) {
            TextField("Nom", text: $newName)
            Button("Annuler", role: .cancel) { }
            Button("Enregistrer") {
                if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    workout.name = newName
                }
            }
        } message: {
            Text("Entrez le nouveau nom de la séance.")
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(workoutTemplate: workout)
        }
    }

    private func startSession() {
        showingActiveWorkout = true
    }

    private func deleteExercise(_ exercise: ExerciseTemplate) {
        modelContext.delete(exercise)
        renumberExercises()
    }

    private func deleteExercises(at offsets: IndexSet) {
        let exercisesToDelete = offsets.map { sortedExercises[$0] }
        for exercise in exercisesToDelete {
            modelContext.delete(exercise)
        }
        renumberExercises()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var exercises = sortedExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in exercises.enumerated() {
            exercise.displayOrder = index
        }
    }

    private func renumberExercises() {
        let exercises = sortedExercises
        for (index, exercise) in exercises.enumerated() {
            exercise.displayOrder = index
        }
    }
}
