import SwiftUI
import SwiftData

struct MuscuLogHistoryContent: View {
    @Query(sort: \CompletedWorkout.date, order: .reverse) private var workouts: [CompletedWorkout]

    var body: some View {
        List {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "Aucune séance",
                    systemImage: "clock",
                    description: Text("Tes séances terminées apparaîtront ici.")
                )
            } else {
                ForEach(workouts) { workout in
                    NavigationLink(destination: destination(for: workout)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.workoutName)
                                .font(.headline)
                            HStack {
                                Text(workout.programName)
                                Text("—")
                                Text(workout.date.formatted(date: .numeric, time: .shortened))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            if workout.finishedAt == nil {
                                Text("Reprendre la séance")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for workout: CompletedWorkout) -> some View {
        if workout.finishedAt == nil {
            ActiveWorkoutView(
                workoutTemplate: WorkoutTemplate(name: workout.workoutName),
                existingWorkout: workout
            )
        } else {
            HistoryDetailView(workout: workout)
        }
    }
}

// Backward compatibility wrapper
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            MuscuLogHistoryContent()
                .navigationTitle("Historique")
        }
    }
}

#Preview {
    NavigationStack {
        MuscuLogHistoryContent()
            .navigationTitle("Historique")
    }
    .modelContainer(for: CompletedWorkout.self, inMemory: true)
}