import Foundation

// MARK: - Format de sauvegarde Nexora (version 3)

/// Sauvegarde complète des données Nexora.
///
/// Tous les champs sont décodés de façon tolérante (`decodeIfPresent`) afin
/// qu'une sauvegarde ancienne reste lisible après l'ajout d'un champ.
struct NexoraBackup: Codable {
    /// Version du format. Incrémentée uniquement lors d'un changement
    /// incompatible ; l'ajout d'un champ optionnel ne change pas la version.
    static let currentVersion = 3

    let version: Int
    let exportDate: Date
    let appVersion: String
    let appBuild: String

    var programs: [BackupProgram] = []
    var workouts: [BackupWorkout] = []
    var movies: [BackupMovie] = []
    var series: [BackupSerie] = []
    var animes: [BackupAnime] = []
    var games: [BackupGame] = []
    var projects: [BackupProject] = []
    var learnings: [BackupLearning] = []
    var favorites: [BackupFavorite] = []
    var settings: BackupSettings?

    enum CodingKeys: String, CodingKey {
        case version, exportDate, appVersion, appBuild
        case programs, workouts, movies, series, animes, games
        case projects, learnings, favorites, settings
    }

    init(
        version: Int = NexoraBackup.currentVersion,
        exportDate: Date = Date(),
        appVersion: String,
        appBuild: String,
        programs: [BackupProgram] = [],
        workouts: [BackupWorkout] = [],
        movies: [BackupMovie] = [],
        series: [BackupSerie] = [],
        animes: [BackupAnime] = [],
        games: [BackupGame] = [],
        projects: [BackupProject] = [],
        learnings: [BackupLearning] = [],
        favorites: [BackupFavorite] = [],
        settings: BackupSettings? = nil
    ) {
        self.version = version
        self.exportDate = exportDate
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.programs = programs
        self.workouts = workouts
        self.movies = movies
        self.series = series
        self.animes = animes
        self.games = games
        self.projects = projects
        self.learnings = learnings
        self.favorites = favorites
        self.settings = settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportDate = try container.decodeIfPresent(Date.self, forKey: .exportDate) ?? Date()
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? "inconnue"
        appBuild = try container.decodeIfPresent(String.self, forKey: .appBuild) ?? "0"
        programs = try container.decodeIfPresent([BackupProgram].self, forKey: .programs) ?? []
        workouts = try container.decodeIfPresent([BackupWorkout].self, forKey: .workouts) ?? []
        movies = try container.decodeIfPresent([BackupMovie].self, forKey: .movies) ?? []
        series = try container.decodeIfPresent([BackupSerie].self, forKey: .series) ?? []
        animes = try container.decodeIfPresent([BackupAnime].self, forKey: .animes) ?? []
        games = try container.decodeIfPresent([BackupGame].self, forKey: .games) ?? []
        projects = try container.decodeIfPresent([BackupProject].self, forKey: .projects) ?? []
        learnings = try container.decodeIfPresent([BackupLearning].self, forKey: .learnings) ?? []
        favorites = try container.decodeIfPresent([BackupFavorite].self, forKey: .favorites) ?? []
        settings = try container.decodeIfPresent(BackupSettings.self, forKey: .settings)
    }

    /// Nombre total d'objets métier contenus dans le fichier.
    var objectCount: Int {
        programs.count + workouts.count + movies.count + series.count + animes.count
            + games.count + projects.count + learnings.count + favorites.count
    }
}
