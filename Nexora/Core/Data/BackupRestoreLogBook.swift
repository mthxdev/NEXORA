import Foundation
import SwiftData

// MARK: - LogBook

@MainActor
extension BackupManager {
    func insertLogBook(_ backup: NexoraBackup, into context: ModelContext) {
        for bm in backup.movies {
            let entry = MovieEntry(
                title: bm.title,
                description: bm.description,
                status: MediaStatus(rawValue: bm.status) ?? .toWatch,
                dateWatched: bm.dateWatched,
                personalRating: bm.personalRating,
                personalComment: bm.personalComment,
                isFavorite: bm.isFavorite,
                externalID: bm.externalID,
                posterURL: bm.posterURL,
                releaseYear: bm.releaseYear
            )
            if let id = bm.id { entry.id = id }
            if let date = bm.dateAdded { entry.dateAdded = date }
            context.insert(entry)
        }

        for bs in backup.series {
            let entry = SeriesEntry(
                title: bs.title,
                description: bs.description,
                status: SeriesStatus(rawValue: bs.status) ?? .toStart,
                currentSeason: bs.currentSeason,
                currentEpisode: bs.currentEpisode,
                totalSeasons: bs.totalSeasons,
                totalEpisodes: bs.totalEpisodes,
                dateCompleted: bs.dateCompleted,
                personalRating: bs.personalRating,
                personalComment: bs.personalComment,
                isFavorite: bs.isFavorite,
                externalID: bs.externalID,
                posterURL: bs.posterURL,
                firstAirYear: bs.firstAirYear
            )
            if let id = bs.id { entry.id = id }
            if let date = bs.dateAdded { entry.dateAdded = date }
            context.insert(entry)
        }

        for ba in backup.animes {
            let entry = AnimeEntry(
                title: ba.title,
                description: ba.description,
                status: SeriesStatus(rawValue: ba.status) ?? .toStart,
                currentSeason: ba.currentSeason,
                currentEpisode: ba.currentEpisode,
                totalSeasons: ba.totalSeasons,
                totalEpisodes: ba.totalEpisodes,
                dateCompleted: ba.dateCompleted,
                personalRating: ba.personalRating,
                personalComment: ba.personalComment,
                isFavorite: ba.isFavorite,
                externalID: ba.externalID,
                posterURL: ba.posterURL,
                firstAirYear: ba.firstAirYear,
                isMovie: ba.isMovie
            )
            if let id = ba.id { entry.id = id }
            if let date = ba.dateAdded { entry.dateAdded = date }
            context.insert(entry)
        }

        for bg in backup.games {
            let entry = GameEntry(
                title: bg.title,
                description: bg.description,
                platform: bg.platform,
                status: MediaStatus(rawValue: bg.status) ?? .toWatch,
                dateCompleted: bg.dateCompleted,
                personalRating: bg.personalRating,
                personalComment: bg.personalComment,
                isFavorite: bg.isFavorite,
                externalID: bg.externalID,
                coverURL: bg.coverURL,
                releaseYear: bg.releaseYear,
                playtimeHours: bg.playtimeHours
            )
            if let id = bg.id { entry.id = id }
            if let date = bg.dateAdded { entry.dateAdded = date }
            context.insert(entry)
        }

        for bp in backup.projects {
            let entry = ProjectEntry(
                name: bp.name,
                description: bp.description,
                status: ProjectStatus(rawValue: bp.status) ?? .planning,
                priority: Priority(rawValue: bp.priority) ?? .medium,
                goal: bp.goal,
                nextStep: bp.nextStep,
                notes: bp.notes,
                isFavorite: bp.isFavorite
            )
            if let id = bp.id { entry.id = id }
            if let date = bp.dateCreated { entry.dateCreated = date }
            if let date = bp.dateModified { entry.dateModified = date }
            entry.dateCompleted = bp.dateCompleted
            context.insert(entry)
        }

        for bl in backup.learnings {
            let entry = LearningEntry(
                name: bl.name,
                description: bl.description,
                status: LearningStatus(rawValue: bl.status) ?? .notStarted,
                dateStarted: bl.dateStarted,
                dateCompleted: bl.dateCompleted,
                goal: bl.goal,
                notes: bl.notes,
                resources: bl.resources,
                isFavorite: bl.isFavorite
            )
            if let id = bl.id { entry.id = id }
            if let date = bl.dateLastUpdated { entry.dateLastUpdated = date }
            context.insert(entry)
        }
    }
}
