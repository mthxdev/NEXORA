import SwiftUI
import SwiftData

struct HistoryDetailView: View {
    let workout: CompletedWorkout

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(workout.date.formatted(date: .long, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Durée")
                    Spacer()
                    if let finishedAt = workout.finishedAt {
                        Text(formatDuration(from: workout.startedAt, to: finishedAt))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("En cours / Non terminée")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if workout.exercises.isEmpty {
                Text("Aucun exercice enregistré.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(workout.exercises.sorted(by: { $0.displayOrder < $1.displayOrder })) { exercise in
                    Section {
                        ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                            HStack {
                                Text("Série \(set.setNumber)")
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("\(String(format: "%g", set.weight)) kg")
                                    .bold()
                                    .frame(width: 70, alignment: .trailing)
                                
                                Text("×")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                
                                Text("\(set.reps) reps")
                                    .bold()
                                    .frame(width: 70, alignment: .leading)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text(exercise.exerciseName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle(workout.workoutName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let diff = Int(end.timeIntervalSince(start))
        let minutes = diff / 60
        return "\(minutes) min"
    }
}
