import Foundation
import SwiftData

// Modèles simplifiés pour l'export JSON
struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let workouts: [BackupWorkout]
}

struct BackupWorkout: Codable {
    let date: Date
    let startedAt: Date
    let finishedAt: Date?
    let programName: String
    let workoutName: String
    let exercises: [BackupExercise]
}

struct BackupExercise: Codable {
    let exerciseName: String
    let displayOrder: Int
    let sets: [BackupSet]
}

struct BackupSet: Codable {
    let weight: Double
    let reps: Int
    let setNumber: Int
}

@MainActor
class BackupManager {
    static let shared = BackupManager()

    /// Exporte toutes les séances complétées dans le dossier Fichiers de l'iPhone
    func autoBackup(context: ModelContext) {
        let descriptor = FetchDescriptor<CompletedWorkout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let workouts = try? context.fetch(descriptor) else { return }

        // Conversion en structures de sauvegarde
        let backupWorkouts = workouts.map { w in
            BackupWorkout(
                date: w.date,
                startedAt: w.startedAt,
                finishedAt: w.finishedAt,
                programName: w.programName,
                workoutName: w.workoutName,
                exercises: w.exercises.map { e in
                    BackupExercise(
                        exerciseName: e.exerciseName,
                        displayOrder: e.displayOrder,
                        sets: e.sets.map { s in
                            BackupSet(weight: s.weight, reps: s.reps, setNumber: s.setNumber)
                        }
                    )
                }
            )
        }

        let data = BackupData(version: 1, exportDate: Date(), workouts: backupWorkouts)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let jsonData = try? encoder.encode(data) else { return }

        // Écriture dans le dossier Documents (visible dans l'app Fichiers d'iOS)
        guard let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileUrl = docsUrl.appendingPathComponent("MuscuLog_Sauvegarde.json")

        try? jsonData.write(to: fileUrl)
    }

    /// Supprime intégralement l'historique de l'application
    func deleteAllData(context: ModelContext) {
        try? context.delete(model: CompletedWorkout.self)
        try? context.delete(model: CompletedExercise.self)
        try? context.delete(model: CompletedSet.self)
        try? context.save()
    }

    /// Importe les données d'un fichier JSON
    func importBackup(from url: URL, context: ModelContext) throws {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: jsonData)

        // Effacer l'ancien historique DÉFINITIVEMENT pour éviter les doublons
        deleteAllData(context: context)

        // Réinsérer toutes les séances
        for bw in backup.workouts {
            let workout = CompletedWorkout(programName: bw.programName, workoutName: bw.workoutName)
            workout.date = bw.date
            workout.startedAt = bw.startedAt
            workout.finishedAt = bw.finishedAt
            context.insert(workout)

            for be in bw.exercises {
                let exercise = CompletedExercise(exerciseName: be.exerciseName, displayOrder: be.displayOrder)
                exercise.workout = workout
                context.insert(exercise)

                for bs in be.sets {
                    let set = CompletedSet(weight: bs.weight, reps: bs.reps, setNumber: bs.setNumber)
                    set.exercise = exercise
                    context.insert(set)
                }
            }
        }
        
        try? context.save()
        // Recréer le fichier auto-backup
        autoBackup(context: context)
    }
}
