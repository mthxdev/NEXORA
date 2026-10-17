import SwiftUI

/// Sous-onglet « Réglages » de MuscuLog : accès direct à la sauvegarde globale.
struct MuscuLogSettingsContent: View {
    var body: some View {
        BackupSettingsView()
            .navigationTitle("Sauvegarde")
    }
}
