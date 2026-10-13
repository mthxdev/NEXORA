import SwiftUI
import SwiftData
import Charts

struct ProgressionView: View {
    @Query(sort: \CompletedWorkout.date, order: .reverse) private var workouts: [CompletedWorkout]

    // Récupère la liste unique des noms d'exercices effectués
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
        NavigationStack {
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
            .navigationTitle("Progression")
        }
    }
}

struct ExerciseProgressionDetail: View {
    let exerciseName: String
    let workouts: [CompletedWorkout]

    // Calcule le poids max soulevé pour chaque date
    var chartData: [(date: Date, maxWeight: Double)] {
        var data: [(Date, Double)] = []
        // On parcourt à l'envers pour avoir l'ordre chronologique (du plus ancien au plus récent)
        for workout in workouts.reversed() {
            if let exercise = workout.exercises.first(where: { $0.exerciseName == exerciseName }) {
                // Trouver le poids max de cette séance
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

