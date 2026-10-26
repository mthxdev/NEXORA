import Foundation
import CryptoKit

// MARK: - Format de sauvegarde Nexora (version 4)

/// Sauvegarde complète des données Nexora.
///
/// Tous les champs sont décodés de façon tolérante (`decodeIfPresent`) afin
/// qu'une sauvegarde ancienne reste lisible après l'ajout d'un champ.
struct NexoraBackup: Codable {
    /// Version du format. Incrémentée uniquement lors d'un changement
    /// incompatible ; l'ajout d'un champ optionnel ne change pas la version.
    static let currentVersion = 4

    let version: Int
    let exportDate: Date
    let appVersion: String
    let appBuild: String

    /// SHA256 du contenu JSON (sans ce champ) pour vérification d'intégrité.
    let checksum: String?

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
        case checksum
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
        // Create a temporary instance to compute checksum
        let tempBackup = NexoraBackup(
            version: version,
            exportDate: exportDate,
            appVersion: appVersion,
            appBuild: appBuild,
            programs: programs,
            workouts: workouts,
            movies: movies,
            series: series,
            animes: animes,
            games: games,
            projects: projects,
            learnings: learnings,
            favorites: favorites,
            settings: settings,
            checksum: nil
        )
        let computedChecksum = Self.computeChecksum(for: tempBackup)
        
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
        self.checksum = computedChecksum
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
        checksum = try container.decodeIfPresent(String.self, forKey: .checksum)
    }

    /// Calcule le SHA256 de la sauvegarde (sans le champ checksum).
    private static func computeChecksum(for backup: NexoraBackup) -> String {
        // Create a copy without checksum by re-encoding all fields except checksum
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        
        // Encode manually without checksum field
        var dict: [String: Any] = [:]
        dict["version"] = backup.version
        dict["exportDate"] = ISO8601DateFormatter().string(from: backup.exportDate)
        dict["appVersion"] = backup.appVersion
        dict["appBuild"] = backup.appBuild
        dict["programs"] = backup.programs
        dict["workouts"] = backup.workouts
        dict["movies"] = backup.movies
        dict["series"] = backup.series
        dict["animes"] = backup.animes
        dict["games"] = backup.games
        dict["projects"] = backup.projects
        dict["learnings"] = backup.learnings
        dict["favorites"] = backup.favorites
        dict["settings"] = backup.settings
        
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Vérifie l'intégrité de la sauvegarde.
    func verifyChecksum() -> Bool {
        guard let expectedChecksum = checksum else { return true }
        let computed = Self.computeChecksum(for: self)
        return computed == expectedChecksum
    }

    /// Nombre total d'objets métier contenus dans le fichier.
    var objectCount: Int {
        programs.count + workouts.count + movies.count + series.count + animes.count
            + games.count + projects.count + learnings.count + favorites.count
    }
}