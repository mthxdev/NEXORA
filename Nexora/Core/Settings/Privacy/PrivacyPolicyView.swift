import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexoraSpacing.md) {
                Group {
                    Text("Confidentialité de Nexora")
                        .font(NexoraTypography.title1)
                        .foregroundStyle(NexoraColors.label)

                    Text("Politique de confidentialité — Version 2.0")
                        .font(NexoraTypography.caption)
                        .foregroundStyle(NexoraColors.secondaryLabel)

                    Text("""
Nexora est une application personnelle. Aucne de vos données n'est jamais collectée, transmise ou partagée avec des services externes. Tout est stocké localement sur votre appareil.
""")
                    .font(NexoraTypography.body)
                    .foregroundStyle(NexoraColors.label)
                }

                VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                    Text("Données stockées localement")
                        .font(NexoraTypography.headline)
                        .foregroundStyle(NexoraColors.label)

                    Text("""
Les données suivantes sont stockées sur votre appareil via SwiftData :

MuscuLog : programmes d'entraînement, modèles de séances, exercices et historique des séances complétées avec leurs séries et performances.

LogBook : votre suivi culturel (films, séries, animés, jeux, projets, apprentissages) avec statut et notes personnelles.

Repas : recettes favorisées et données de planification de repas.
""")
                        .font(NexoraTypography.body)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }

                VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                    Text("Sauvegarde")
                        .font(NexoraTypography.headline)
                        .foregroundStyle(NexoraColors.label)

                    Text("""
Un fichier JSON (MuscuLog_Sauvegarde.json) est généré automatiquement et enregistré dans le dossier Fichiers de votre iPhone. Vous pouvez l'exporter via l'app Fichiers ou le partager manuellement. Vous pouvez également l'importer pour restaurer vos données.

Cette sauvegarde contient uniquement vos programmes et l'historique des séances. Elle est chiffrée par iOS lorsque le stockage est chiffré.
""")
                        .font(NexoraTypography.body)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }

                VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                    Text("Permissions")
                        .font(NexoraTypography.headline)
                        .foregroundStyle(NexoraColors.label)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Notifications", systemImage: "bell")
                            .font(NexoraTypography.subheadline)
                            .foregroundStyle(NexoraColors.label)
                        Text("Utilisées uniquement pour les rappels d'entraînement que vous activez volontairement.")
                            .font(NexoraTypography.caption)
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Accès aux fichiers", systemImage: "doc")
                            .font(NexoraTypography.subheadline)
                            .foregroundStyle(NexoraColors.label)
                        Text("Permet l'import et l'export de vos sauvegardes JSON.")
                            .font(NexoraTypography.caption)
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }

                VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                    Text("Limites")
                        .font(NexoraTypography.headline)
                        .foregroundStyle(NexoraColors.label)

                    Text("""
• Les recettes de repas proviennent d'une liste intégrée (SampleRecipes). Aucune donnée n'est récupérée depuis Internet.

• Le LogBook peut utiliser des identifiants externes (externalID) pour référencer des œuvres, mais ces champs restent vides tant que vous n'entrezez pas manuellement ces identifiants.

• Aucun service en ligne, analytics, ou tracking n'est intégré. Aucune connexion réseau n'est requise pour l'essentiel du fonctionnement.

• Désinstaller l'application supprime toutes les données stockées localement.
""")
                        .font(NexoraTypography.body)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }

                Divider()

                Text("© 2025-2026 Mathieu. Tous droits réservés.")
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.tertiaryLabel)
                    .frame(maxWidth: .infinity)
            }
            .padding(NexoraSpacing.xl)
            .padding(.top)
        }
        .background(NexoraColors.groupedBackground)
        .navigationTitle("Confidentialité")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
