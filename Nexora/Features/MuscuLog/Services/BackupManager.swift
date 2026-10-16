import Foundation
import SwiftData

// Modèles simplifiés pour l'export JSON
struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let programs: [BackupProgram]
    let workouts: [BackupWorkout]

    init(version: Int, exportDate: Date, programs: [BackupProgram] = [], workouts: [BackupWorkout]) {
        self.version = version
        self.exportDate = exportDate
        self.programs = programs
        self.workouts = workouts
    }

    enum CodingKeys: String, CodingKey {
        case version, exportDate, programs, workouts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportDate = try container.decode(Date.self, forKey: .exportDate)
        programs = try container.decodeIfPresent([BackupProgram].self, forKey: .programs) ?? []
        workouts = try container.decode([BackupWorkout].self, forKey: .workouts)
    }
}

struct BackupProgram: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let workouts: [BackupWorkoutTemplate]
}

struct BackupWorkoutTemplate: Codable {
    let id: UUID
    let name: String
    let displayOrder: Int
    let exercises: [BackupExerciseTemplate]
}

struct BackupExerciseTemplate: Codable {
    let id: UUID
    let name: String
    let targetSets: Int
    let targetReps: String
    let displayOrder: Int
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

    /// Exporte toutes les séances complétées et les programmes dans le dossier Fichiers de l'iPhone
    func autoBackup(context: ModelContext) {
        let programDescriptor = FetchDescriptor<Program>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let workoutDescriptor = FetchDescriptor<CompletedWorkout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        
        guard let programs = try? context.fetch(programDescriptor) else { return }
        guard let workouts = try? context.fetch(workoutDescriptor) else { return }

        // Conversion en structures de sauvegarde
        let backupPrograms = programs.map { p in
            BackupProgram(
                id: p.id,
                name: p.name,
                createdAt: p.createdAt,
                workouts: p.workouts.sorted(by: { $0.displayOrder < $1.displayOrder }).map { w in
                    BackupWorkoutTemplate(
                        id: w.id,
                        name: w.name,
                        displayOrder: w.displayOrder,
                        exercises: w.exercises.sorted(by: { $0.displayOrder < $1.displayOrder }).map { e in
                            BackupExerciseTemplate(
                                id: e.id,
                                name: e.name,
                                targetSets: e.targetSets,
                                targetReps: e.targetReps,
                                displayOrder: e.displayOrder
                            )
                        }
                    )
                }
            )
        }

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

        let data = BackupData(version: 2, exportDate: Date(), programs: backupPrograms, workouts: backupWorkouts)
        
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
        try? context.delete(model: Program.self)
        try? context.delete(model: WorkoutTemplate.self)
        try? context.delete(model: ExerciseTemplate.self)
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

        // Réinsérer tous les programmes (templates)
        for bp in backup.programs {
            let program = Program(name: bp.name)
            program.id = bp.id
            program.createdAt = bp.createdAt
            context.insert(program)

            for bw in bp.workouts {
                let workout = WorkoutTemplate(name: bw.name, displayOrder: bw.displayOrder)
                workout.id = bw.id
                workout.program = program
                context.insert(workout)

                for be in bw.exercises {
                    let exercise = ExerciseTemplate(
                        name: be.name,
                        targetSets: be.targetSets,
                        targetReps: be.targetReps,
                        displayOrder: be.displayOrder
                    )
                    exercise.id = be.id
                    exercise.workout = workout
                    context.insert(exercise)
                }
            }
        }

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
