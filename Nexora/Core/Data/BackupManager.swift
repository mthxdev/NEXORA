import Foundation
import SwiftData

/// Résultat d'une restauration, destiné à l'interface.
struct RestoreReport {
    let programs: Int
    let workouts: Int
    let logBookEntries: Int
    let favorites: Int
    let sourceVersion: Int

    var total: Int { programs + workouts + logBookEntries + favorites }
}

enum BackupError: LocalizedError {
    case unreadableFile
    case invalidJSON(String)
    case unsupportedVersion(Int)
    case emptyBackup
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "Le fichier n'a pas pu être ouvert."
        case .invalidJSON(let detail):
            return "Ce fichier n'est pas une sauvegarde Nexora valide (\(detail))."
        case .unsupportedVersion(let version):
            return "Cette sauvegarde utilise un format (version \(version)) que cette version de Nexora ne sait pas lire."
        case .emptyBackup:
            return "La sauvegarde ne contient aucune donnée à restaurer."
        case .saveFailed(let detail):
            return "Les données n'ont pas pu être enregistrées : \(detail)"
        }
    }
}

@MainActor
final class BackupManager {
    static let shared = BackupManager()

    /// Nom du fichier écrit dans le dossier Documents.
    static let backupFileName = "Nexora_Sauvegarde.json"

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Export

    /// Construit la sauvegarde complète à partir du contexte SwiftData.
    /// Lève une erreur plutôt que de produire silencieusement un fichier partiel.
    func makeBackup(context: ModelContext) throws -> NexoraBackup {
        let programs = try context.fetch(
            FetchDescriptor<Program>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )
        let workouts = try context.fetch(
            FetchDescriptor<CompletedWorkout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
        let movies = try context.fetch(FetchDescriptor<MovieEntry>())
        let series = try context.fetch(FetchDescriptor<SeriesEntry>())
        let animes = try context.fetch(FetchDescriptor<AnimeEntry>())
        let games = try context.fetch(FetchDescriptor<GameEntry>())
        let projects = try context.fetch(FetchDescriptor<ProjectEntry>())
        let learnings = try context.fetch(FetchDescriptor<LearningEntry>())
        let favorites = try context.fetch(FetchDescriptor<FavoriteRecipe>())

        let defaults = UserDefaults.standard

        return NexoraBackup(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
            appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0",
            programs: programs.map(Self.backupProgram(from:)),
            workouts: workouts.map(Self.backupWorkout(from:)),
            movies: movies.map(Self.backupMovie(from:)),
            series: series.map(Self.backupSerie(from:)),
            animes: animes.map(Self.backupAnime(from:)),
            games: games.map(Self.backupGame(from:)),
            projects: projects.map(Self.backupProject(from:)),
            learnings: learnings.map(Self.backupLearning(from:)),
            favorites: favorites.map {
                BackupFavorite(id: $0.id, recipeID: $0.recipeID, dateAdded: $0.dateAdded)
            },
            settings: BackupSettings(
                appearance: defaults.string(forKey: "appearance"),
                notificationsEnabled: defaults.bool(forKey: "notificationsEnabled"),
                reminderTimeSeconds: defaults.object(forKey: "reminderTime") as? Double
            )
        )
    }

    /// Encode et écrit la sauvegarde dans Documents. Retourne l'URL du fichier.
    @discardableResult
    func writeBackup(context: ModelContext) throws -> URL {
        let backup = try makeBackup(context: context)
        let data = try Self.encoder.encode(backup)
        let url = try Self.documentsURL(fileName: Self.backupFileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Sauvegarde automatique, appelée au lancement et après une séance.
    ///
    /// Écrit dans le dossier Documents de l'application, exposé dans Fichiers
    /// grâce à `UIFileSharingEnabled`. Ce fichier **ne survit pas** à une
    /// désinstallation : ce n'est pas une sauvegarde externe.
    @discardableResult
    func autoBackup(context: ModelContext) -> URL? {
        do {
            let url = try writeBackup(context: context)
            UserDefaults.standard.set(Date(), forKey: "lastAutoBackupDate")
            return url
        } catch {
            print("BackupManager: sauvegarde automatique impossible — \(error)")
            return nil
        }
    }

    /// Date de la dernière sauvegarde automatique réussie.
    var lastAutoBackupDate: Date? {
        UserDefaults.standard.object(forKey: "lastAutoBackupDate") as? Date
    }

    // MARK: - Import

    /// Décode un fichier de sauvegarde sans toucher aux données existantes.
    nonisolated func decodeBackup(from data: Data) throws -> NexoraBackup {
        let backup: NexoraBackup
        do {
            backup = try Self.decoder.decode(NexoraBackup.self, from: data)
        } catch {
            throw BackupError.invalidJSON(error.localizedDescription)
        }

        guard backup.version <= NexoraBackup.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        guard backup.objectCount > 0 else {
            throw BackupError.emptyBackup
        }
        return backup
    }

    /// Remplace les données par le contenu de la sauvegarde.
    ///
    /// Séquence : lecture et validation complètes → instantané des données
    /// actuelles en mémoire → remplacement → enregistrement. Si l'enregistrement
    /// échoue, l'instantané est réappliqué pour éviter une perte partielle.
    @discardableResult
    func restore(from backup: NexoraBackup, context: ModelContext) throws -> RestoreReport {
        // Instantané de secours, avant toute suppression.
        let fallback: NexoraBackup
        do {
            fallback = try makeBackup(context: context)
        } catch {
            throw BackupError.saveFailed("instantané de sécurité impossible (\(error.localizedDescription))")
        }

        do {
            try deleteAllData(context: context)
            try insert(backup, into: context)
            try context.save()
        } catch {
            // Tentative de retour à l'état précédent.
            do {
                try deleteAllData(context: context)
                try insert(fallback, into: context)
                try context.save()
            } catch {
                print("BackupManager: retour arrière impossible — \(error)")
            }
            throw BackupError.saveFailed(error.localizedDescription)
        }

        applySettings(backup.settings)

        return RestoreReport(
            programs: backup.programs.count,
            workouts: backup.workouts.count,
            logBookEntries: backup.movies.count + backup.series.count + backup.animes.count
                + backup.games.count + backup.projects.count + backup.learnings.count,
            favorites: backup.favorites.count,
            sourceVersion: backup.version
        )
    }

    /// Point d'entrée pratique : restaure depuis un fichier choisi par l'utilisateur.
    @discardableResult
    func restore(from url: URL, context: ModelContext) throws -> RestoreReport {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsScope { url.stopAccessingSecurityScopedResource() }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.unreadableFile
        }

        let backup = try decodeBackup(from: data)
        let report = try restore(from: backup, context: context)
        autoBackup(context: context)
        return report
    }

    // MARK: - Suppression

    /// Supprime toutes les données de tous les modules.
    func deleteAllData(context: ModelContext) throws {
        try context.delete(model: CompletedSet.self)
        try context.delete(model: CompletedExercise.self)
        try context.delete(model: CompletedWorkout.self)
        try context.delete(model: ExerciseTemplate.self)
        try context.delete(model: WorkoutTemplate.self)
        try context.delete(model: Program.self)
        try context.delete(model: MovieEntry.self)
        try context.delete(model: SeriesEntry.self)
        try context.delete(model: AnimeEntry.self)
        try context.delete(model: GameEntry.self)
        try context.delete(model: ProjectEntry.self)
        try context.delete(model: LearningEntry.self)
        try context.delete(model: FavoriteRecipe.self)
        try context.save()
    }

    nonisolated static func documentsURL(fileName: String) throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BackupError.unreadableFile
        }
        return docs.appendingPathComponent(fileName)
    }
}
