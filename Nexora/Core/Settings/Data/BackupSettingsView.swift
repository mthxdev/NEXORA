import SwiftUI
import SwiftData
import UIKit

/// Feuille de partage système, pour exporter le fichier de sauvegarde.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct BackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showingFileImporter = false
    @State private var showingDeleteConfirm = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false

    @State private var pendingBackup: NexoraBackup?
    @State private var showingRestoreConfirm = false

    private var lastBackupText: String {
        guard let date = BackupManager.shared.lastAutoBackupDate else {
            return "Aucune sauvegarde automatique enregistrée pour l'instant."
        }
        return "Dernière sauvegarde : \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        List {
            backupSection
            dangerSection
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .alert("Supprimer toutes les données ?", isPresented: $showingDeleteConfirm) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer définitivement", role: .destructive) {
                deleteEverything()
            }
        } message: {
            Text("Cette action est irréversible et concerne tous les modules.")
        }
        .alert("Restaurer cette sauvegarde ?", isPresented: $showingRestoreConfirm) {
            Button("Annuler", role: .cancel) { pendingBackup = nil }
            Button("Remplacer mes données", role: .destructive) {
                performRestore()
            }
        } message: {
            Text(restoreConfirmationMessage)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
    }

    // MARK: - Sections


    private var backupSection: some View {
        Section {
            Text("""
            Une sauvegarde complète est écrite dans le dossier Documents de \
            l'application à chaque lancement et à la fin d'une séance. Elle couvre \
            MuscuLog, LogBook, les favoris de Repas et vos réglages.

            Cette copie automatique est visible dans l'application Fichiers : \
            Parcourir → Emplacements → Nexora. Elle ne survit pas à une \
            désinstallation de l'application.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)

            Label(lastBackupText, systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                createBackupAndShare()
            } label: {
                Label("Exporter une copie", systemImage: "square.and.arrow.up")
            }
            .accessibilityHint("Crée une copie exportable à conserver dans iCloud Drive ou Fichiers")

            Button {
                showingFileImporter = true
            } label: {
                Label("Importer et restaurer", systemImage: "arrow.down.doc")
            }
        } header: {
            Text("Sauvegarde")
        } footer: {
            Text("""
            Pour un changement d'iPhone : utilisez « Exporter une copie », \
            choisissez « Enregistrer dans Fichiers » puis « iCloud Drive ». \
            Sur le nouvel iPhone, ouvrez Nexora → Réglages → Sauvegarde → \
            « Importer et restaurer ».
            """)
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Supprimer toutes les données", systemImage: "trash")
            }
        } header: {
            Text("Zone de danger")
        } footer: {
            Text("Efface les données de tous les modules : MuscuLog, LogBook et Repas. Action irréversible.")
        }
    }

    private var restoreConfirmationMessage: String {
        guard let backup = pendingBackup else { return "" }
        let logBook = backup.movies.count + backup.series.count + backup.animes.count
            + backup.games.count + backup.projects.count + backup.learnings.count
        return """
        Fichier du \(backup.exportDate.formatted(date: .abbreviated, time: .shortened)) \
        (version \(backup.version)) : \(backup.programs.count) programme(s), \
        \(backup.workouts.count) séance(s), \(logBook) élément(s) de LogBook.

        Vos données actuelles seront remplacées. Un instantané est conservé \
        sur disque et réappliqué si l'opération échoue.
        """
    }

    // MARK: - Actions

    private func createBackupAndShare() {
        do {
            exportURL = try MainActor.assumeIsolated {
                try BackupManager.shared.writeBackup(context: modelContext)
            }
            showingShareSheet = true
        } catch {
            present(title: "Export impossible", message: error.localizedDescription)
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                // Validation complète avant toute modification des données.
                pendingBackup = try BackupManager.shared.decodeBackup(from: data)
                showingRestoreConfirm = true
            } catch {
                present(title: "Fichier non valide", message: error.localizedDescription)
            }
        case .failure(let error):
            present(title: "Lecture impossible", message: error.localizedDescription)
        }
    }

    private func performRestore() {
        guard let backup = pendingBackup else { return }
        defer { pendingBackup = nil }
        do {
            let report = try MainActor.assumeIsolated {
                try BackupManager.shared.restore(from: backup, context: modelContext)
            }
            present(
                title: "Restauration terminée",
                message: """
                \(report.programs) programme(s), \(report.workouts) séance(s), \
                \(report.logBookEntries) élément(s) de LogBook et \
                \(report.favorites) favori(s) restaurés.
                """
            )
        } catch {
            present(title: "Restauration impossible", message: error.localizedDescription)
        }
    }

    private func deleteEverything() {
        do {
            // Instantané écrit avant la suppression, par sécurité.
            try MainActor.assumeIsolated {
                try BackupManager.shared.writeBackup(context: modelContext)
                try BackupManager.shared.deleteAllData(context: modelContext)
            }
            present(
                title: "Données supprimées",
                message: "Toutes les données ont été effacées. Une sauvegarde du dernier état a été conservée dans le dossier Documents."
            )
        } catch {
            present(title: "Suppression impossible", message: error.localizedDescription)
        }
    }

    private func present(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// Backward compatibility wrapper
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            BackupSettingsView()
                .navigationTitle("Réglages")
        }
    }
}

#Preview {
    NavigationStack {
        BackupSettingsView()
            .navigationTitle("Réglages")
    }
    .modelContainer(
        for: [Program.self, CompletedWorkout.self, MovieEntry.self, FavoriteRecipe.self],
        inMemory: true
    )
}

