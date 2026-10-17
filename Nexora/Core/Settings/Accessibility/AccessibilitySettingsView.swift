import SwiftUI

struct AccessibilitySettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityInvertColors) private var invertColors
    @Environment(\.accessibilityBoldText) private var boldText
    @AppStorage("reduceTransitions") private var reduceTransitions: Bool = false

    var body: some View {
        Form {
            Section("iOS") {
                NavigationLink(destination: systemSettingsView) {
                    Label("Réglages d'accessibilité", systemImage: "accessibility")
                }
            }

            Section("État actuel") {
                StatusRow(label: "Réduction du mouvement", isEnabled: reduceMotion)
                StatusRow(label: "Différenciation sans couleur", isEnabled: differentiateWithoutColor)
                StatusRow(label: "Inversion des couleurs", isEnabled: invertColors)
                StatusRow(label: "Texte gras", isEnabled: boldText)
            }

            Section {
                Toggle("Réduire les animations de transition", isOn: $reduceTransitions)
                    .accessibilityLabel("Réduire les animations de transition")
            } footer: {
                Text("Désactive les animations entre les écrans pour une navigation plus fluide sur les appareils plus anciens.")
            }
        }
        .navigationTitle("Accessibilité")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var systemSettingsView: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text("Ouvrez les réglages iOS")
                .font(NexoraTypography.headline)
            Text("Utilisez les paramètres d'accessibilité natifs d'iOS pour :")
                .font(NexoraTypography.subheadline)
                .foregroundStyle(NexoraColors.secondaryLabel)

            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text("• Grossir le texte et ajuster la taille dynamique")
                Text("• Activer le lecteur d'écran (VoiceOver)")
                Text("• Activer le mode grande taille")
                Text("• Ajuster le contraste et la luminosité")
            }
            .padding(.top, NexoraSpacing.sm)

            Spacer()
        }
        .padding()
        .background(NexoraColors.groupedBackground)
        .navigationTitle("Réglages iOS")
    }

    struct StatusRow: View {
        let label: String
        let isEnabled: Bool

        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Text(isEnabled ? "Activé" : "Désactivé")
                    .foregroundStyle(isEnabled ? .green : NexoraColors.secondaryLabel)
            }
            .font(NexoraTypography.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
    }
}
