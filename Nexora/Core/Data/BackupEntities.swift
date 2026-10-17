// MARK: - MuscuLog

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
    let id: UUID?
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

// MARK: - LogBook

struct BackupMovie: Codable {
    var id: UUID?
    var title: String
    var description: String = ""
    var status: String = MediaStatus.toWatch.rawValue
    var dateAdded: Date?
    var dateWatched: Date?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool = false
    var externalID: String?
    var posterURL: String?
    var releaseYear: Int?
}

struct BackupSerie: Codable {
    var id: UUID?
    var title: String
    var description: String = ""
    var status: String = SeriesStatus.toStart.rawValue
    var dateAdded: Date?
    var dateCompleted: Date?
    var currentSeason: Int = 1
    var currentEpisode: Int = 0
    var totalSeasons: Int?
    var totalEpisodes: Int?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool = false
    var externalID: String?
    var posterURL: String?
    var firstAirYear: Int?
}

struct BackupAnime: Codable {
    var id: UUID?
    var title: String
    var description: String = ""
    var status: String = SeriesStatus.toStart.rawValue
    var dateAdded: Date?
    var dateCompleted: Date?
    var currentSeason: Int = 1
    var currentEpisode: Int = 0
    var totalSeasons: Int?
    var totalEpisodes: Int?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool = false
    var externalID: String?
    var posterURL: String?
    var firstAirYear: Int?
    var isMovie: Bool = false
}

struct BackupGame: Codable {
    var id: UUID?
    var title: String
    var description: String = ""
    var platform: String = ""
    var status: String = MediaStatus.toWatch.rawValue
    var dateAdded: Date?
    var dateCompleted: Date?
    var personalRating: Int?
    var personalComment: String?
    var isFavorite: Bool = false
    var externalID: String?
    var coverURL: String?
    var releaseYear: Int?
    var playtimeHours: Double?
}

struct BackupProject: Codable {
    var id: UUID?
    var name: String
    var description: String = ""
    var status: String = ProjectStatus.planning.rawValue
    var priority: String = Priority.medium.rawValue
    var dateCreated: Date?
    var dateModified: Date?
    var dateCompleted: Date?
    var goal: String?
    var nextStep: String?
    var notes: String = ""
    var isFavorite: Bool = false
}

struct BackupLearning: Codable {
    var id: UUID?
    var name: String
    var description: String = ""
    var status: String = LearningStatus.notStarted.rawValue
    var dateStarted: Date?
    var dateCompleted: Date?
    var dateLastUpdated: Date?
    var goal: String = ""
    var notes: String = ""
    var resources: String = ""
    var isFavorite: Bool = false
}

// MARK: - Repas & réglages

struct BackupFavorite: Codable {
    var id: UUID?
    var recipeID: String
    var dateAdded: Date?
}

/// Réglages utilisateur pertinents (pas les données de sécurité iOS).
struct BackupSettings: Codable {
    var appearance: String?
    var notificationsEnabled: Bool?
    var reminderTimeSeconds: Double?
}
