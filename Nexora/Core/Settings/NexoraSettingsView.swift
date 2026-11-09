import SwiftUI
import UIKit

@MainActor
struct NexoraSettingsView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @StateObject private var iconSelection = AppIconSelectionModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAbout = false
    #if DIAGNOSTIC
    @State private var showingDebugExport = false
    @State private var debugExportAlert = false
    #endif
    
    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                
                logoSection
                
                generalSection
                
                dataSection
                
                #if DIAGNOSTIC
                diagnosticSection
                #endif
                
                aboutSection
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAbout) {
                AboutView(selectedLogo: iconSelection.selectedLogo)
            }
            .alert("Changement d’icône impossible", isPresented: Binding(
                get: { iconSelection.errorMessage != nil },
                set: { if !$0 { iconSelection.clearError() } }
            )) {
                Button("OK", role: .cancel) { iconSelection.clearError() }
            } message: {
                Text(iconSelection.errorMessage ?? "")
            }
            #if DIAGNOSTIC
            .sheet(isPresented: $showingDebugExport) {
                DebugShareSheet(items: [DebugLog.shared.prepareExport()])
            }
            .alert("Aucun journal", isPresented: $debugExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Le fichier de diagnostic est vide ou absent.")
            }
            #endif
        }
        .onAppear {
            iconSelection.refreshFromSystem()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                iconSelection.refreshFromSystem()
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
    
    private var logoSection: some View {
        Section {
            Picker("Icône de l’application", selection: Binding<AppLogo?>(
                get: { iconSelection.selectedLogo },
                set: { logo in
                    guard let logo else { return }
                    Task { await iconSelection.select(logo) }
                }
            )) {
                ForEach(AppLogo.allCases, id: \.self) { logo in
                    HStack(spacing: NexoraSpacing.sm) {
                        Image(logo.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(logo.displayName)
                    }
                        .tag(Optional(logo))
                }
            }
            .pickerStyle(.menu)
            .disabled(iconSelection.isApplying || !iconSelection.supportsAlternateIcons)
            if iconSelection.selectedLogo == nil {
                Text("L’icône système active ne correspond à aucune option connue.")
                    .font(.footnote)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                Button("Revenir à l’icône principale") {
                    Task { await iconSelection.select(.classic) }
                }
                .disabled(iconSelection.isApplying || !iconSelection.supportsAlternateIcons)
            }
            if !iconSelection.supportsAlternateIcons {
                Text("Le changement d’icône n’est pas pris en charge dans cet environnement.")
                    .font(.footnote)
                    .foregroundStyle(NexoraColors.secondaryLabel)
            }
        } header: {
            Text("Logo")
        } footer: {
            Text("L’icône active est synchronisée avec iOS. iOS peut afficher une confirmation lors du changement.")
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
            NavigationLink(destination: BackupSettingsView()) {
                Label("Sauvegarde & données", systemImage: "externaldrive")
            }
            .accessibilityLabel("Sauvegarde et données")
            .accessibilityHint("Exporter, restaurer ou supprimer vos données")
        } header: {
            Text("Données")
        } footer: {
            Text("Export, restauration et suppression s'appliquent à l'ensemble des modules.")
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
    
    // DEBUG — Diagnostic section
    #if DIAGNOSTIC
    private var diagnosticSection: some View {
        Section("Diagnostic") {
            Button("Exporter journal de crash") {
                if DebugLog.shared.hasContent {
                    showingDebugExport = true
                } else {
                    debugExportAlert = true
                }
            }
        }
    }
    #endif
    
    private var versionFooter: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Nexora \(version) (\(build))"
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedLogo: AppLogo?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NexoraSpacing.lg) {
                    if let selectedLogo {
                        Image(selectedLogo.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .accessibilityLabel("Logo Nexora")
                    }
                    
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
