import SwiftUI
import SwiftData
import Charts

struct MuscuLogProgressionContent: View {
    @Query(sort: \CompletedWorkout.date, order: .reverse) private var workouts: [CompletedWorkout]

    var uniqueExercises: [String] {
        var names = Set<String>()
        for workout in workouts {
            for exercise in workout.exercises {
                names.insert(exercise.exerciseName)
            }
        }
        return Array(names).sorted()
    }

    var body: some View {
        List {
            if uniqueExercises.isEmpty {
                ContentUnavailableView(
                    "Aucune donnée",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Termine des séances pour voir ton évolution.")
                )
            } else {
                ForEach(uniqueExercises, id: \.self) { exerciseName in
                    NavigationLink(destination: ExerciseProgressionDetail(exerciseName: exerciseName, workouts: workouts)) {
                        Text(exerciseName)
                            .font(.headline)
                    }
                }
            }
        }
    }
}

struct ExerciseProgressionDetail: View {
    let exerciseName: String
    let workouts: [CompletedWorkout]

    var chartData: [(date: Date, maxWeight: Double)] {
        var data: [(Date, Double)] = []
        for workout in workouts.reversed() {
            if let exercise = workout.exercises.first(where: { $0.exerciseName == exerciseName }) {
                let maxWeight = exercise.sets.map { $0.weight }.max() ?? 0
                if maxWeight > 0 {
                    data.append((workout.date, maxWeight))
                }
            }
        }
        return data
    }

    var body: some View {
        List {
            Section {
                if chartData.count >= 2 {
                    Chart(chartData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Poids Max (kg)", item.maxWeight)
                        )
                        .symbol(Circle())
                        .interpolationMethod(.monotone)
                    }
                    .frame(height: 250)
                    .padding(.vertical)
                } else {
                    Text("Complète cet exercice sur au moins 2 séances différentes pour générer le graphique.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical)
                }
            } header: {
                Text("Évolution du Poids Max")
            }

            Section {
                ForEach(chartData.reversed(), id: \.date) { item in
                    HStack {
                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text("\(String(format: "%g", item.maxWeight)) kg")
                            .bold()
                    }
                }
            } header: {
                Text("Historique des records")
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Backward compatibility wrapper
struct ProgressionView: View {
    var body: some View {
        NavigationStack {
            MuscuLogProgressionContent()
                .navigationTitle("Progression")
        }
    }
}

#Preview {
    NavigationStack {
        MuscuLogProgressionContent()
            .navigationTitle("Progression")
    }
    .modelContainer(for: CompletedWorkout.self, inMemory: true)
}