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
    case noBackupFolderSelected
    case securityScopeFailed

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
        case .noBackupFolderSelected:
            return "Aucun dossier de sauvegarde externe n'a été choisi. Allez dans Réglages > Sauvegarde pour en choisir un."
        case .securityScopeFailed:
            return "Impossible d'accéder au dossier de sauvegarde. Veuillez le sélectionner à nouveau dans les réglages."
        }
    }
}

final class BackupManager {
    static let shared = BackupManager()

    /// Nom du fichier écrit dans le dossier Documents.
    static let backupFileName = "Nexora_Sauvegarde.json"

    /// Fichier temporaire de secours écrit avant une restauration.
    /// Survit à un crash de l'application pendant la restauration.
    static let restoreFallbackFileName = ".Nexora_Restore_Fallback.json"

    /// Clé UserDefaults pour stocker le bookmark du dossier de sauvegarde externe.
    private static let backupFolderBookmarkKey = "externalBackupFolderBookmark"

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    nonisolated private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - External Backup Folder Management

    /// Bookmark data for the external backup folder (stored in UserDefaults).
    @MainActor
    private var backupFolderBookmarkData: Data? {
        get { UserDefaults.standard.data(forKey: Self.backupFolderBookmarkKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.backupFolderBookmarkKey) }
    }

    /// Résout l'URL du dossier externe à partir du bookmark stocké.
    @MainActor
    private func resolveExternalBackupFolder() -> URL? {
        guard let bookmarkData = backupFolderBookmarkData else { return nil }
        var isStale = false
        do {
            // On iOS, resolve WITHOUT .withSecurityScope option
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                // Refresh stale bookmark
                let newBookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                backupFolderBookmarkData = newBookmark
            }
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                return nil
            }
            return url
        } catch {
            return nil
        }
    }

    /// URL du dossier de sauvegarde externe choisi par l'utilisateur (si configuré et accessible).
    @MainActor
    var externalBackupFolderURL: URL? {
        resolveExternalBackupFolder()
    }

    /// Vérifie si un dossier de sauvegarde externe est configuré et accessible.
    @MainActor
    var hasExternalBackupFolder: Bool {
        externalBackupFolderURL != nil
    }

    /// Configure le dossier de sauvegarde externe à partir d'une URL choisie par l'utilisateur.
    @MainActor
    func setExternalBackupFolder(_ url: URL) {
        do {
            #if os(iOS)
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #endif
            backupFolderBookmarkData = bookmark
        } catch {
            print("BackupManager: failed to save folder bookmark — \(error)")
        }
    }

    /// Supprime la référence au dossier de sauvegarde externe.
    @MainActor
    func clearExternalBackupFolder() {
        backupFolderBookmarkData = nil
    }

    // MARK: - Export

    /// Construit la sauvegarde complète à partir du contexte SwiftData.
    /// Lève une erreur plutôt que de produire silencieusement un fichier partiel.
    @MainActor
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
            projects: projects.map(Self.backupProjectEntry(from:)),
            learnings: learnings.map(Self.backupLearningEntry(from:)),
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
    @MainActor
    @discardableResult
    func writeBackup(context: ModelContext) throws -> URL {
        let backup = try makeBackup(context: context)
        let data = try Self.encoder.encode(backup)
        let url = try Self.documentsURL(fileName: Self.backupFileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Écrit une sauvegarde dans un dossier externe choisi par l'utilisateur.
    /// Retourne l'URL du fichier créé.
    @MainActor
    @discardableResult
    func writeExternalBackup(context: ModelContext) throws -> URL {
        guard let folderURL = externalBackupFolderURL else {
            throw BackupError.noBackupFolderSelected
        }
        // The URL from resolveExternalBackupFolder already has security scope started
        // No need to call startAccessingSecurityScopedResource again

        let backup = try makeBackup(context: context)
        let data = try Self.encoder.encode(backup)
        let fileName = "Nexora_Sauvegarde_\(ISO8601DateFormatter().string(from: Date())).json"
        let url = folderURL.appendingPathComponent(fileName)
        
        try data.write(to: url, options: .atomic)
        
        // Mettre à jour la date de dernière sauvegarde externe
        UserDefaults.standard.set(Date(), forKey: "lastExternalBackupDate")
        
        return url
    }

    /// Sauvegarde externe déclenchée après une opération importante (version synchrone pour Task.detached).
    @MainActor
    func performExternalBackup(context: ModelContext) throws -> URL {
        try writeExternalBackup(context: context)
    }

    /// Sauvegarde automatique, appelée au lancement et après une séance.
    ///
    /// Écrit dans le dossier Documents de l'application, exposé dans Fichiers
    /// grâce à `UIFileSharingEnabled`. Ce fichier **ne survit pas** à une
    /// désinstallation : ce n'est pas une sauvegarde externe.
    @MainActor
    @discardableResult
    func autoBackup(context: ModelContext) -> URL? {
        do {
            let url = try writeBackup(context: context)
            UserDefaults.standard.set(Date(), forKey: "lastAutoBackupDate")
            
            // Si un dossier externe est configuré, faire aussi une sauvegarde externe
            if hasExternalBackupFolder {
                do {
                    try writeExternalBackup(context: context)
                } catch {
                    print("BackupManager: sauvegarde externe automatique impossible — \(error)")
                }
            }
            
            return url
        } catch {
            print("BackupManager: sauvegarde automatique impossible — \(error)")
            return nil
        }
    }

    /// Sauvegarde externe déclenchée après une opération importante.
    @MainActor
    func backupAfterImportantOperation(context: ModelContext) {
        guard hasExternalBackupFolder else { return }
        
        // Éviter les sauvegardes trop fréquentes (minimum 5 minutes)
        let lastDate = UserDefaults.standard.object(forKey: "lastExternalBackupDate") as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastDate) > 300 else { return }
        
        Task.detached { @MainActor [weak self] in
            guard let self else { return }
            do {
                try self.writeExternalBackup(context: context)
            } catch {
                print("BackupManager: sauvegarde externe asynchrone impossible — \(error)")
            }
        }
    }

    /// Vérifie si un dossier de sauvegarde externe est configuré et accessible.
    @MainActor
    var hasExternalBackupFolder: Bool {
        externalBackupFolderURL != nil
    }

    /// Date de la dernière sauvegarde automatique réussie.
    nonisolated var lastAutoBackupDate: Date? {
        UserDefaults.standard.object(forKey: "lastAutoBackupDate") as? Date
    }

    /// Date de la dernière sauvegarde externe réussie.
    nonisolated var lastExternalBackupDate: Date? {
        UserDefaults.standard.object(forKey: "lastExternalBackupDate") as? Date
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
    /// Séquence : snapshot en mémoire → snapshot sur disque → effacement →
    /// insertion → enregistrement. Si l'enregistrement échoue, le snapshot
    /// sur disque est utilisé en dernier recours si le snapshot en mémoire
    /// est également inutilisable (par exemple après un crash interne).
    @MainActor
    @discardableResult
    func restore(from backup: NexoraBackup, context: ModelContext) throws -> RestoreReport {
        // 1. Snapshot en mémoire pour un rollback rapide.
        let fallback: NexoraBackup
        do {
            fallback = try makeBackup(context: context)
        } catch {
            throw BackupError.saveFailed("instantané de sécurité impossible (\(error.localizedDescription))")
        }

        // 2. Snapshot sur disque : résiste à un crash de l'application.
        let fallbackURL: URL? = try? Self.documentsURL(fileName: Self.restoreFallbackFileName)
        if let fallbackURL {
            do {
                let fallbackData = try Self.encoder.encode(fallback)
                try fallbackData.write(to: fallbackURL, options: .atomic)
            } catch {
                print("BackupManager: fallback sur disque impossible — \(error)")
            }
        }

        // 3. Opération de restauration.
        do {
            try deleteAllData(context: context)
            try insert(backup, into: context)
            try context.save()
        } catch {
            // 4. Tentative de rollback depuis le snapshot en mémoire.
            let restoreError = error
            do {
                try deleteAllData(context: context)
                try insert(fallback, into: context)
                try context.save()
                print("BackupManager: données précédentes restaurées depuis l'instantané en mémoire.")
            } catch {
                print("BackupManager: rollback mémoire échoué — \(error)")

                // 5. Dernier recours : snapshot sur disque.
                if let diskURL = fallbackURL,
                   FileManager.default.fileExists(atPath: diskURL.path) {
                    do {
                        let diskData = try Data(contentsOf: diskURL)
                        let diskBackup = try decodeBackup(from: diskData)
                        try deleteAllData(context: context)
                        try insert(diskBackup, into: context)
                        try context.save()
                        print("BackupManager: données restaurées depuis le fallback sur disque.")
                    } catch {
                        print("BackupManager: fallback disque également échoué — \(error)")
                        throw BackupError.saveFailed(
                            "la restauration a échoué et les données ne peuvent pas être récupérées (\(restoreError.localizedDescription))"
                        )
                    }
                } else {
                    throw BackupError.saveFailed(
                        "la restauration a échoué et les données ne peuvent pas être récupérées (\(restoreError.localizedDescription))"
                    )
                }
            }
        }

        // 6. Nettoyage du fichier de secours.
        if let fallbackURL {
            try? FileManager.default.removeItem(at: fallbackURL)
        }

        // 7. Application des réglages et retour du rapport.
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
    @MainActor
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

    /// Tente de récupérer les données après un crash pendant une restauration.
    ///
    /// À appeler au lancement de l'application, avant `autoBackup`.
    /// Si un fichier de fallback orphelin est présent (créé par une restauration
    /// interrompue), tente de restaurer les données depuis ce fichier.
    /// Nettoie toujours le fichier de fallback, quelle que soit l'issue.
    @MainActor
    @discardableResult
    func recoverFromFallback(context: ModelContext) -> Bool {
        guard let fallbackURL = try? Self.documentsURL(fileName: Self.restoreFallbackFileName),
              FileManager.default.fileExists(atPath: fallbackURL.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: fallbackURL)
            let backup = try decodeBackup(from: data)
            try restore(from: backup, context: context)
            print("BackupManager: données récupérées depuis le fallback après crash.")
        } catch {
            print("BackupManager: récupération depuis le fallback échouée — \(error)")
            // Même si la récupération échoue, on nettoie le fichier.
        }

        try? FileManager.default.removeItem(at: fallbackURL)
        return true
    }

    // MARK: - Suppression

    /// Supprime toutes les données de tous les modules.
    @MainActor
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

    // MARK: - Helpers pour la sérialisation

    private static func backupProgram(from program: Program) -> BackupProgram {
        BackupProgram(
            id: program.id,
            name: program.name,
            createdAt: program.createdAt,
            workouts: program.workouts.map { BackupWorkoutTemplate(
                id: $0.id,
                name: $0.name,
                displayOrder: $0.displayOrder,
                exercises: $0.exercises.map { BackupExerciseTemplate(
                    id: $0.id,
                    name: $0.name,
                    targetSets: $0.targetSets,
                    targetReps: $0.targetReps,
                    displayOrder: $0.displayOrder
                )}
            )}
        )
    }

    private static func backupWorkout(from workout: CompletedWorkout) -> BackupWorkout {
        BackupWorkout(
            id: workout.id,
            date: workout.date,
            startedAt: workout.startedAt,
            finishedAt: workout.finishedAt,
            programName: workout.programName,
            workoutName: workout.workoutName,
            exercises: workout.exercises.sorted(by: { $0.displayOrder < $1.displayOrder }).map {
                BackupExercise(
                    exerciseName: $0.exerciseName,
                    displayOrder: $0.displayOrder,
                    sets: $0.sets.sorted(by: { $0.setNumber < $1.setNumber }).map {
                        BackupSet(weight: $0.weight, reps: $0.reps, setNumber: $0.setNumber)
                    }
                )
            }
        )
    }

    private static func backupMovie(from movie: MovieEntry) -> BackupMovie {
        BackupMovie(
            id: movie.id,
            title: movie.title,
            description: movie.movieDescription,
            status: movie.status.rawValue,
            dateAdded: movie.dateAdded,
            dateWatched: movie.dateWatched,
            personalRating: movie.personalRating,
            personalComment: movie.personalComment,
            isFavorite: movie.isFavorite,
            externalID: movie.externalID,
            posterURL: movie.posterURL,
            releaseYear: movie.releaseYear
        )
    }

    private static func backupSerie(from series: SeriesEntry) -> BackupSerie {
        BackupSerie(
            id: series.id,
            title: series.title,
            description: series.seriesDescription,
            status: series.status.rawValue,
            dateAdded: series.dateAdded,
            dateCompleted: series.dateCompleted,
            currentSeason: series.currentSeason,
            currentEpisode: series.currentEpisode,
            totalSeasons: series.totalSeasons,
            totalEpisodes: series.totalEpisodes,
            personalRating: series.personalRating,
            personalComment: series.personalComment,
            isFavorite: series.isFavorite,
            externalID: series.externalID,
            posterURL: series.posterURL,
            firstAirYear: series.firstAirYear
        )
    }

    private static func backupAnime(from anime: AnimeEntry) -> BackupAnime {
        BackupAnime(
            id: anime.id,
            title: anime.title,
            description: anime.animeDescription,
            status: anime.status.rawValue,
            dateAdded: anime.dateAdded,
            dateCompleted: anime.dateCompleted,
            currentSeason: anime.currentSeason,
            currentEpisode: anime.currentEpisode,
            totalSeasons: anime.totalSeasons,
            totalEpisodes: anime.totalEpisodes,
            personalRating: anime.personalRating,
            personalComment: anime.personalComment,
            isFavorite: anime.isFavorite,
            externalID: anime.externalID,
            posterURL: anime.posterURL,
            firstAirYear: anime.firstAirYear,
            isMovie: anime.isMovie
        )
    }

    private static func backupGame(from game: GameEntry) -> BackupGame {
        BackupGame(
            id: game.id,
            title: game.title,
            description: game.gameDescription,
            platform: game.platform,
            status: game.status.rawValue,
            dateAdded: game.dateAdded,
            dateCompleted: game.dateCompleted,
            personalRating: game.personalRating,
            personalComment: game.personalComment,
            isFavorite: game.isFavorite,
            externalID: game.externalID,
            coverURL: game.coverURL,
            releaseYear: game.releaseYear,
            playtimeHours: game.playtimeHours
        )
    }

    private static func backupProjectEntry(from project: ProjectEntry) -> BackupProject {
        BackupProject(
            id: project.id,
            name: project.name,
            description: project.projectDescription,
            status: project.status.rawValue,
            priority: project.priority.rawValue,
            dateCreated: project.dateCreated,
            dateModified: project.dateModified,
            dateCompleted: project.dateCompleted,
            goal: project.goal,
            nextStep: project.nextStep,
            notes: project.notes,
            isFavorite: project.isFavorite
        )
    }

    private static func backupLearningEntry(from learning: LearningEntry) -> BackupLearning {
        BackupLearning(
            id: learning.id,
            name: learning.name,
            description: learning.learningDescription,
            status: learning.status.rawValue,
            dateStarted: learning.dateStarted,
            dateCompleted: learning.dateCompleted,
            dateLastUpdated: learning.dateLastUpdated,
            goal: learning.goal,
            notes: learning.notes,
            resources: learning.resources,
            isFavorite: learning.isFavorite
        )
    }

    private static func backupWorkoutTemplate(from template: WorkoutTemplate) -> BackupWorkoutTemplate {
        BackupWorkoutTemplate(
            id: template.id,
            name: template.name,
            displayOrder: template.displayOrder,
            exercises: template.exercises.map { BackupExerciseTemplate(
                id: $0.id,
                name: $0.name,
                targetSets: $0.targetSets,
                targetReps: $0.targetReps,
                displayOrder: $0.displayOrder
            )}
        )
    }

    private static func backupExercise(from template: ExerciseTemplate) -> BackupExerciseTemplate {
        BackupExerciseTemplate(
            id: template.id,
            name: template.name,
            targetSets: template.targetSets,
            targetReps: template.targetReps,
            displayOrder: template.displayOrder
        )
    }
}