import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingFileImporter = false
    
    // Alertes
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Alerte destructive
    @State private var showingDeleteConfirm = false
    
    // Alerte de restauration
    @State private var showingImportAlert = false
    @State private var importedURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("À chaque fois que tu termines une séance, MuscuLog génère automatiquement un fichier de sauvegarde dans l'application Fichiers (dossier 'Sur mon iPhone' > MuscuLog).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        BackupManager.shared.autoBackup(context: modelContext)
                        alertTitle = "Succès"
                        alertMessage = "La sauvegarde a été forcée. Le dossier MuscuLog devrait maintenant être visible dans l'application Fichiers."
                        showingAlert = true
                    } label: {
                        Label("Forcer la création du dossier", systemImage: "folder.badge.plus")
                    }

                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Restaurer depuis une sauvegarde", systemImage: "arrow.down.doc")
                    }
                } header: {
                    Text("Sauvegarde automatique")
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Tout supprimer", systemImage: "trash")
                    }
                } header: {
                    Text("Zone de danger")
                } footer: {
                    Text("Efface instantanément tout l'historique et la progression.")
                }
            }
            .navigationTitle("Réglages")
            
            // Alerte de confirmation de suppression totale
            .alert("Supprimer tout l'historique ?", isPresented: $showingDeleteConfirm) {
                Button("Annuler", role: .cancel) { }
                Button("Supprimer définitivement", role: .destructive) {
                    BackupManager.shared.deleteAllData(context: modelContext)
                    alertTitle = "Suppression réussie"
                    alertMessage = "Toutes les séances ont été effacées de l'historique."
                    showingAlert = true
                }
            } message: {
                Text("Cette action est irréversible. Toutes tes séances et statistiques de progression seront effacées.")
            }
            
            // Alerte d'information générique (Succès ou Erreur)
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
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importedURL = url
                        showingImportAlert = true
                    }
                case .failure(let error):
                    alertTitle = "Erreur"
                    alertMessage = "Impossible de lire le fichier : \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            .alert("Confirmer la restauration", isPresented: $showingImportAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Restaurer", role: .destructive) {
                    if let url = importedURL {
                        do {
                            try BackupManager.shared.importBackup(from: url, context: modelContext)
                            alertTitle = "Restauration réussie"
                            alertMessage = "L'historique a été importé avec succès !"
                            showingAlert = true
                        } catch {
                            alertTitle = "Erreur de restauration"
                            alertMessage = "Le fichier JSON est invalide ou corrompu. Erreur: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                }
            } message: {
                Text("Attention : Restaurer une sauvegarde va effacer ton historique actuel pour le remplacer par celui du fichier. Veux-tu continuer ?")
            }
        }
    }
}
