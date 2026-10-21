import Foundation
import SwiftData

@Model
final class MovieEntry: Identifiable {
    var id: UUID
    var title: String
    var movieDescription: String
    var status: MediaStatus
    var dateAdded: Date
    var dateWatched: Date?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool
    var externalID: String?
    var posterURL: String?
    var releaseYear: Int?
    
    init(
        title: String,
        description: String = "",
        status: MediaStatus = .toWatch,
        dateWatched: Date? = nil,
        personalRating: Int? = nil,
        personalComment: String? = nil,
        isFavorite: Bool = false,
        externalID: String? = nil,
        posterURL: String? = nil,
        releaseYear: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.movieDescription = description
        self.status = status
        self.dateAdded = Date()
        self.dateWatched = dateWatched
        self.personalRating = personalRating
        self.personalComment = personalComment
        self.isFavorite = isFavorite
        self.externalID = externalID
        self.posterURL = posterURL
        self.releaseYear = releaseYear
    }
}

@Model
final class SeriesEntry: Identifiable {
    var id: UUID
    var title: String
    var seriesDescription: String
    var status: SeriesStatus
    var dateAdded: Date
    var dateCompleted: Date?
    var currentSeason: Int
    var currentEpisode: Int
    var totalSeasons: Int?
    var totalEpisodes: Int?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool
    var externalID: String?
    var posterURL: String?
    var firstAirYear: Int?
    
    var progressPercentage: Double {
        guard let totalSeasons, let totalEpisodes, totalEpisodes > 0 else { return 0 }
        let completedEpisodes = (currentSeason - 1) * (totalEpisodes / max(totalSeasons, 1)) + currentEpisode
        return min(Double(completedEpisodes) / Double(totalEpisodes), 1.0)
    }
    
    init(
        title: String,
        description: String = "",
        status: SeriesStatus = .toStart,
        currentSeason: Int = 1,
        currentEpisode: Int = 0,
        totalSeasons: Int? = nil,
        totalEpisodes: Int? = nil,
        dateCompleted: Date? = nil,
        personalRating: Int? = nil,
        personalComment: String? = nil,
        isFavorite: Bool = false,
        externalID: String? = nil,
        posterURL: String? = nil,
        firstAirYear: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.seriesDescription = description
        self.status = status
        self.dateAdded = Date()
        self.dateCompleted = dateCompleted
        self.currentSeason = max(1, currentSeason)
        self.currentEpisode = max(0, currentEpisode)
        self.totalSeasons = totalSeasons
        self.totalEpisodes = totalEpisodes
        self.personalRating = personalRating
        self.personalComment = personalComment
        self.isFavorite = isFavorite
        self.externalID = externalID
        self.posterURL = posterURL
        self.firstAirYear = firstAirYear
    }
}

@Model
final class AnimeEntry: Identifiable {
    var id: UUID
    var title: String
    var animeDescription: String
    var status: SeriesStatus
    var dateAdded: Date
    var dateCompleted: Date?
    var currentSeason: Int
    var currentEpisode: Int
    var totalSeasons: Int?
    var totalEpisodes: Int?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool
    var externalID: String?
    var posterURL: String?
    var firstAirYear: Int?
    var isMovie: Bool
    
    var progressPercentage: Double {
        guard let totalEpisodes, totalEpisodes > 0 else { return 0 }
        let completedEpisodes = (currentSeason - 1) * (totalEpisodes / max(totalSeasons ?? 1, 1)) + currentEpisode
        return min(Double(completedEpisodes) / Double(totalEpisodes), 1.0)
    }
    
    init(
        title: String,
        description: String = "",
        status: SeriesStatus = .toStart,
        currentSeason: Int = 1,
        currentEpisode: Int = 0,
        totalSeasons: Int? = nil,
        totalEpisodes: Int? = nil,
        dateCompleted: Date? = nil,
        personalRating: Int? = nil,
        personalComment: String? = nil,
        isFavorite: Bool = false,
        externalID: String? = nil,
        posterURL: String? = nil,
        firstAirYear: Int? = nil,
        isMovie: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.animeDescription = description
        self.status = status
        self.dateAdded = Date()
        self.dateCompleted = dateCompleted
        self.currentSeason = max(1, currentSeason)
        self.currentEpisode = max(0, currentEpisode)
        self.totalSeasons = totalSeasons
        self.totalEpisodes = totalEpisodes
        self.personalRating = personalRating
        self.personalComment = personalComment
        self.isFavorite = isFavorite
        self.externalID = externalID
        self.posterURL = posterURL
        self.firstAirYear = firstAirYear
        self.isMovie = isMovie
    }
}

@Model
final class GameEntry: Identifiable {
    var id: UUID
    var title: String
    var gameDescription: String
    var platform: String
    var status: MediaStatus
    var dateAdded: Date
    var dateCompleted: Date?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool
    var externalID: String?
    var coverURL: String?
    var releaseYear: Int?
    var playtimeHours: Double?
    
    init(
        title: String,
        description: String = "",
        platform: String = "",
        status: MediaStatus = .toWatch,
        dateCompleted: Date? = nil,
        personalRating: Int? = nil,
        personalComment: String? = nil,
        isFavorite: Bool = false,
        externalID: String? = nil,
        coverURL: String? = nil,
        releaseYear: Int? = nil,
        playtimeHours: Double? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.gameDescription = description
        self.platform = platform
        self.status = status
        self.dateAdded = Date()
        self.dateCompleted = dateCompleted
        self.personalRating = personalRating
        self.personalComment = personalComment
        self.isFavorite = isFavorite
        self.externalID = externalID
        self.coverURL = coverURL
        self.releaseYear = releaseYear
        self.playtimeHours = playtimeHours
    }
}

@Model
final class ProjectEntry: Identifiable {
    var id: UUID
    var name: String
    var projectDescription: String
    var status: ProjectStatus
    var priority: Priority
    var dateCreated: Date
    var dateModified: Date
    var dateCompleted: Date?
    var goal: String?
    var nextStep: String?
    var notes: String
    var isFavorite: Bool
    
    init(
        name: String,
        description: String = "",
        status: ProjectStatus = .planning,
        priority: Priority = .medium,
        goal: String? = nil,
        nextStep: String? = nil,
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.projectDescription = description
        self.status = status
        self.priority = priority
        self.dateCreated = Date()
        self.dateModified = Date()
        self.goal = goal
        self.nextStep = nextStep
        self.notes = notes
        self.isFavorite = isFavorite
    }
}

@Model
final class LearningEntry: Identifiable {
    var id: UUID
    var name: String
    var learningDescription: String
    var status: LearningStatus
    var dateStarted: Date?
    var dateCompleted: Date?
    var dateLastUpdated: Date
    var goal: String
    var notes: String
    var resources: String
    var isFavorite: Bool
    
    init(
        name: String,
        description: String = "",
        status: LearningStatus = .notStarted,
        dateStarted: Date? = nil,
        dateCompleted: Date? = nil,
        goal: String = "",
        notes: String = "",
        resources: String = "",
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.learningDescription = description
        self.status = status
        self.dateStarted = dateStarted
        self.dateCompleted = dateCompleted
        self.dateLastUpdated = Date()
        self.goal = goal
        self.notes = notes
        self.resources = resources
        self.isFavorite = isFavorite
    }
}