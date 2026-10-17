import Foundation
import SwiftData

// MARK: - Insertion des données restaurées

@MainActor
extension BackupManager {
    func insert(_ backup: NexoraBackup, into context: ModelContext) throws {
        insertPrograms(backup.programs, into: context)
        insertWorkouts(backup.workouts, into: context)
        insertLogBook(backup, into: context)
        insertFavorites(backup.favorites, into: context)
    }

    private func insertPrograms(_ programs: [BackupProgram], into context: ModelContext) {
        for bp in programs {
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
    }

    private func insertWorkouts(_ workouts: [BackupWorkout], into context: ModelContext) {
        for bw in workouts {
            let workout = CompletedWorkout(programName: bw.programName, workoutName: bw.workoutName)
            if let id = bw.id { workout.id = id }
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
    }

    private func insertFavorites(_ favorites: [BackupFavorite], into context: ModelContext) {
        for bf in favorites {
            let favorite = FavoriteRecipe(recipeID: bf.recipeID)
            if let id = bf.id { favorite.id = id }
            if let date = bf.dateAdded { favorite.dateAdded = date }
            context.insert(favorite)
        }
    }

    func applySettings(_ settings: BackupSettings?) {
        guard let settings else { return }
        let defaults = UserDefaults.standard
        if let appearance = settings.appearance {
            defaults.set(appearance, forKey: "appearance")
        }
        if let enabled = settings.notificationsEnabled {
            defaults.set(enabled, forKey: "notificationsEnabled")
        }
        if let seconds = settings.reminderTimeSeconds {
            defaults.set(seconds, forKey: "reminderTime")
        }
    }
}
