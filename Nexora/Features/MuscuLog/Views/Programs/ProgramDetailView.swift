import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var program: Program

    @State private var showingEditProgram = false
    @State private var showingActiveWorkout = false
    @State private var startWorkoutTemplate: WorkoutTemplate?

    var sortedWorkouts: [WorkoutTemplate] {
        program.workouts.sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        List {
            Section {
                if sortedWorkouts.isEmpty {
                    Text("Aucune séance. Ajoute-en une pour commencer !")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedWorkouts) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name)
                                    .font(.headline)
                                Text("\(workout.exercises.count) exercice\(workout.exercises.count > 1 ? "s" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteWorkouts)
                }
            } header: {
                Text("Séances")
            }
        }
        .navigationTitle(program.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        addWorkoutAutomatically()
                    } label: {
                        Label("Ajouter une séance", systemImage: "plus")
                    }
                    Button {
                        showingEditProgram = true
                    } label: {
                        Label("Renommer le programme", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditProgram) {
            ProgramFormView(program: program)
        }
        .safeAreaInset(edge: .bottom) {
            if let firstWorkout = sortedWorkouts.first {
                Button {
                    startWorkoutTemplate = firstWorkout
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
        .fullScreenCover(item: $startWorkoutTemplate) { template in
            ActiveWorkoutView(workoutTemplate: template)
        }
    }

    private func addWorkoutAutomatically() {
        let newName = "Séance \(program.workouts.count + 1)"
        let newWorkout = WorkoutTemplate(name: newName, displayOrder: program.workouts.count)
        newWorkout.program = program
        modelContext.insert(newWorkout)
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        let workoutsToDelete = offsets.map { sortedWorkouts[$0] }
        for workout in workoutsToDelete {
            modelContext.delete(workout)
        }
    }
}
