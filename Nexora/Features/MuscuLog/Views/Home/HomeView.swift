import SwiftUI
import SwiftData

struct MuscuLogHomeContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query(sort: \CompletedWorkout.date, order: .reverse) private var completedWorkouts: [CompletedWorkout]

    @State private var showingAddProgram = false
    @State private var showingResumeWorkout = false
    @State private var workoutToStart: WorkoutTemplate?

    private var unfinishedWorkout: CompletedWorkout? {
        completedWorkouts.first(where: { $0.finishedAt == nil })
    }

    var body: some View {
        List {
            if let unfinishedWorkout {
                Section {
                    Button {
                        showingResumeWorkout = true
                    } label: {
                        Label("Reprendre \(unfinishedWorkout.workoutName)", systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                } header: {
                    Text("Séance en cours")
                }
            }

            // Dernière séance
            if let lastWorkout = completedWorkouts.first(where: { $0.finishedAt != nil }) {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lastWorkout.workoutName)
                            .font(.headline)
                        Text("\(lastWorkout.programName) — \(lastWorkout.date.formatted(date: .long, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Dernière séance")
                }
            }

            // Programmes
            Section {
                if programs.isEmpty {
                    ContentUnavailableView(
                        "Aucun programme",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Crée ton premier programme pour commencer à t'entraîner.")
                    )
                } else {
                    ForEach(programs) { program in
                        VStack(alignment: .leading, spacing: 6) {
                            NavigationLink(destination: ProgramDetailView(program: program)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(program.name)
                                        .font(.headline)
                                    Text("\(program.workouts.count) séance\(program.workouts.count > 1 ? "s" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)

                            if !program.workouts.isEmpty {
                                Button {
                                    startSession(for: program)
                                } label: {
                                    Label("Démarrer la séance", systemImage: "play.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor)
                                        .foregroundStyle(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onDelete(perform: deletePrograms)
                }
            } header: {
                Text("Mes programmes")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddProgram = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProgram) {
            ProgramFormView()
        }
        .fullScreenCover(isPresented: $showingResumeWorkout) {
            if let unfinishedWorkout {
                ActiveWorkoutView(
                    workoutTemplate: matchingTemplate(for: unfinishedWorkout),
                    existingWorkout: unfinishedWorkout
                )
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { workoutToStart != nil },
            set: { _ in workoutToStart = nil }
        )) {
            if let template = workoutToStart {
                ActiveWorkoutView(workoutTemplate: template)
            }
        }
    }

    private func startSession(for program: Program) {
        guard let firstWorkout = program.workouts.sorted(by: { $0.displayOrder < $1.displayOrder }).first else { return }
        workoutToStart = firstWorkout
    }

    private func matchingTemplate(for workout: CompletedWorkout) -> WorkoutTemplate {
        programs
            .first(where: { $0.name == workout.programName })?
            .workouts
            .first(where: { $0.name == workout.workoutName })
            ?? WorkoutTemplate(name: workout.workoutName)
    }

    private func deletePrograms(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(programs[index])
        }
    }
}

// Backward compatibility wrapper
struct HomeView: View {
    var body: some View {
        NavigationStack {
            MuscuLogHomeContent()
                .navigationTitle("MuscuLog")
        }
    }
}

#Preview {
    NavigationStack {
        MuscuLogHomeContent()
            .navigationTitle("MuscuLog")
    }
    .modelContainer(for: [Program.self, CompletedWorkout.self], inMemory: true)
}
