import Foundation
import SwiftData

// MARK: - Conversion modèle → sauvegarde

extension BackupManager {
    nonisolated static func backupProgram(from p: Program) -> BackupProgram {
        BackupProgram(
            id: p.id,
            name: p.name,
            createdAt: p.createdAt,
            workouts: p.workouts
                .sorted { $0.displayOrder < $1.displayOrder }
                .map { w in
                    BackupWorkoutTemplate(
                        id: w.id,
                        name: w.name,
                        displayOrder: w.displayOrder,
                        exercises: w.exercises
                            .sorted { $0.displayOrder < $1.displayOrder }
                            .map { e in
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

    nonisolated static func backupWorkout(from w: CompletedWorkout) -> BackupWorkout {
        BackupWorkout(
            id: w.id,
            date: w.date,
            startedAt: w.startedAt,
            finishedAt: w.finishedAt,
            programName: w.programName,
            workoutName: w.workoutName,
            exercises: w.exercises
                .sorted { $0.displayOrder < $1.displayOrder }
                .map { e in
                    BackupExercise(
                        exerciseName: e.exerciseName,
                        displayOrder: e.displayOrder,
                        sets: e.sets
                            .sorted { $0.setNumber < $1.setNumber }
                            .map { BackupSet(weight: $0.weight, reps: $0.reps, setNumber: $0.setNumber) }
                    )
                }
        )
    }

    nonisolated static func backupMovie(from m: MovieEntry) -> BackupMovie {
        BackupMovie(
            id: m.id,
            title: m.title,
            description: m.movieDescription,
            status: m.status.rawValue,
            dateAdded: m.dateAdded,
            dateWatched: m.dateWatched,
            personalRating: m.personalRating,
            personalComment: m.personalComment,
            isFavorite: m.isFavorite,
            externalID: m.externalID,
            posterURL: m.posterURL,
            releaseYear: m.releaseYear
        )
    }

    nonisolated static func backupSerie(from s: SeriesEntry) -> BackupSerie {
        BackupSerie(
            id: s.id,
            title: s.title,
            description: s.seriesDescription,
            status: s.status.rawValue,
            dateAdded: s.dateAdded,
            dateCompleted: s.dateCompleted,
            currentSeason: s.currentSeason,
            currentEpisode: s.currentEpisode,
            totalSeasons: s.totalSeasons,
            totalEpisodes: s.totalEpisodes,
            personalRating: s.personalRating,
            personalComment: s.personalComment,
            isFavorite: s.isFavorite,
            externalID: s.externalID,
            posterURL: s.posterURL,
            firstAirYear: s.firstAirYear
        )
    }

    nonisolated static func backupAnime(from a: AnimeEntry) -> BackupAnime {
        BackupAnime(
            id: a.id,
            title: a.title,
            description: a.animeDescription,
            status: a.status.rawValue,
            dateAdded: a.dateAdded,
            dateCompleted: a.dateCompleted,
            currentSeason: a.currentSeason,
            currentEpisode: a.currentEpisode,
            totalSeasons: a.totalSeasons,
            totalEpisodes: a.totalEpisodes,
            personalRating: a.personalRating,
            personalComment: a.personalComment,
            isFavorite: a.isFavorite,
            externalID: a.externalID,
            posterURL: a.posterURL,
            firstAirYear: a.firstAirYear,
            isMovie: a.isMovie
        )
    }

    nonisolated static func backupGame(from g: GameEntry) -> BackupGame {
        BackupGame(
            id: g.id,
            title: g.title,
            description: g.gameDescription,
            platform: g.platform,
            status: g.status.rawValue,
            dateAdded: g.dateAdded,
            dateCompleted: g.dateCompleted,
            personalRating: g.personalRating,
            personalComment: g.personalComment,
            isFavorite: g.isFavorite,
            externalID: g.externalID,
            coverURL: g.coverURL,
            releaseYear: g.releaseYear,
            playtimeHours: g.playtimeHours
        )
    }

    nonisolated static func backupProject(from p: ProjectEntry) -> BackupProject {
        BackupProject(
            id: p.id,
            name: p.name,
            description: p.projectDescription,
            status: p.status.rawValue,
            priority: p.priority.rawValue,
            dateCreated: p.dateCreated,
            dateModified: p.dateModified,
            dateCompleted: p.dateCompleted,
            goal: p.goal,
            nextStep: p.nextStep,
            notes: p.notes,
            isFavorite: p.isFavorite
        )
    }

    nonisolated static func backupLearning(from l: LearningEntry) -> BackupLearning {
        BackupLearning(
            id: l.id,
            name: l.name,
            description: l.learningDescription,
            status: l.status.rawValue,
            dateStarted: l.dateStarted,
            dateCompleted: l.dateCompleted,
            dateLastUpdated: l.dateLastUpdated,
            goal: l.goal,
            notes: l.notes,
            resources: l.resources,
            isFavorite: l.isFavorite
        )
    }
}
