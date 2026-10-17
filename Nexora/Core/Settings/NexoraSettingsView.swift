import SwiftUI

struct NexoraSettingsView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @State private var showingAbout = false
    
    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                
                generalSection
                
                dataSection
                
                aboutSection
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
    
    private var appearanceSection: some View {
        Section {
            Picker("Apparence", selection: $appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { appearance in
                    Label(appearance.rawValue, systemImage: appearance.icon)
                        .tag(appearance)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Apparence")
        } footer: {
            Text("Le thème suit le réglage système par défaut.")
        }
    }
    
    private var generalSection: some View {
        Section {
            NavigationLink(destination: NotificationSettingsView()) {
                Label("Notifications", systemImage: "bell.badge")
            }
            .accessibilityLabel("Réglages des notifications")

            NavigationLink(destination: PrivacyPolicyView()) {
                Label("Confidentialité", systemImage: "lock.shield")
            }
            .accessibilityLabel("Politique de confidentialité")

            NavigationLink(destination: AccessibilitySettingsView()) {
                Label("Accessibilité", systemImage: "accessibility")
            }
            .accessibilityLabel("Réglages d'accessibilité")
        } header: {
            Text("Général")
        }
    }
    
    private var dataSection: some View {
        Section {
            NavigationLink(destination: MuscuLogSettingsContent()) {
                Label("Sauvegarde & restauration", systemImage: "externaldrive.badge.icloud")
            }
            
            NavigationLink(destination: Text("Export de données - À venir")) {
                Label("Exporter mes données", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Exporter mes données")

            NavigationLink(destination: Text("Supprimer toutes les données - À venir")) {
                Label("Effacer toutes les données", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Effacer toutes les données")
            .accessibilityHint("Supprime définitivement toutes les données de l'application")
        } header: {
            Text("Données")
        } footer: {
            Text("Chaque module gère ses propres données. Les options de sauvegarde sont disponibles par module.")
        }
    }
    
    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                HStack {
                    Label("À propos de Nexora", systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(NexoraColors.tertiaryLabel)
                }
            }
            .foregroundStyle(NexoraColors.label)
            .accessibilityLabel("À propos de Nexora")

            Link(destination: URL(string: "https://github.com")!) {
                Label("Code source", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .accessibilityLabel("Code source sur GitHub")

            Link(destination: URL(string: "https://github.com")!) {
                Label("Signaler un problème", systemImage: "exclamationmark.bubble")
            }
            .accessibilityLabel("Signaler un problème")
        } header: {
            Text("À propos")
        } footer: {
            Text(versionFooter)
        }
    }
    
    private var versionFooter: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Nexora \(version) (\(build))"
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NexoraSpacing.lg) {
                    Image("NexoraLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityLabel("Logo Nexora")
                    
                    VStack(spacing: NexoraSpacing.xs) {
                        Text("Nexora")
                            .font(NexoraTypography.largeTitle)
                        
                        Text(versionString)
                            .font(NexoraTypography.subheadline)
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                    
                    Text("Application utilitaire personnelle évolutive.\nRegroupe vos modules quotidiens en un seul endroit.")
                        .font(NexoraTypography.body)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NexoraSpacing.xl)
                    
                    Divider()
                        .padding(.horizontal, NexoraSpacing.xl)
                    
                    VStack(alignment: .leading, spacing: NexoraSpacing.md) {
                        ModuleInfoRow(icon: "dumbbell.fill", color: .blue, title: "MuscuLog", description: "Suivi musculation complet avec programmes, séances et progression")
                        ModuleInfoRow(icon: "book.fill", color: .purple, title: "LogBook", description: "Films, séries, animés, jeux, projets, apprentissages (à venir)")
                    ModuleInfoRow(icon: "carrot.fill", color: .orange, title: "Repas", description: "Recettes culinaires avec planification, nutrition estimée et favoris")
                    }
                    .padding(.horizontal, NexoraSpacing.xl)
                    
                    Spacer()
                    
                    Text("Développé avec Swift & SwiftUI")
                        .font(NexoraTypography.caption)
                        .foregroundStyle(NexoraColors.tertiaryLabel)
                }
                .padding(.vertical, NexoraSpacing.xl)
            }
            .background(NexoraColors.groupedBackground)
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
    
    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

struct ModuleInfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: NexoraSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: NexoraRadius.md)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NexoraTypography.headline)
                Text(description)
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.secondaryLabel)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(description)")
    }
}

#Preview {
    NexoraSettingsView()
}