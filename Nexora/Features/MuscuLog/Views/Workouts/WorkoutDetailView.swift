import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: WorkoutTemplate

    @State private var showingAddExercise = false
    @State private var showingActiveWorkout = false
    @State private var showingRename = false
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
                        newName = workout.name
                        showingRename = true
                    } label: {
                        Label("Renommer la séance", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !sortedExercises.isEmpty {
                Button {
                    showingActiveWorkout = true
                } label: {
                    Text("Démarrer la séance")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            ExerciseFormView(workout: workout)
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(workoutTemplate: workout)
        }
        .alert("Renommer la séance", isPresented: $showingRename) {
            TextField("Nom", text: $newName)
            Button("Annuler", role: .cancel) { }
            Button("Enregistrer") {
                workout.name = newName
            }
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        let exercisesToDelete = offsets.map { sortedExercises[$0] }
        for exercise in exercisesToDelete {
            modelContext.delete(exercise)
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var exercises = sortedExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in exercises.enumerated() {
            exercise.displayOrder = index
        }
    }
}
