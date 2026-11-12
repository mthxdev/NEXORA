import SwiftUI

private struct OpenNexoraSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openNexoraSettings: () -> Void {
        get { self[OpenNexoraSettingsKey.self] }
        set { self[OpenNexoraSettingsKey.self] = newValue }
    }
}

struct NexoraSettingsToolbarButton: View {
    @Environment(\.openNexoraSettings) private var openSettings

    var body: some View {
        Button(action: openSettings) {
            Label("Réglages", systemImage: "gearshape")
        }
        .labelStyle(.titleAndIcon)
        .accessibilityLabel("Réglages")
    }
}

enum AppTab: Hashable, CaseIterable {
    case home
    case muscuLog
    case logBook
    case repas
    case chill
}

struct AppCoordinator: View {
    @State private var selectedTab: AppTab = .home
    @State private var showingSettings = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NexoraHomeView()
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }
                .tag(AppTab.home)
            
            MuscuLogTabView()
                .tabItem {
                    Label("MuscuLog", systemImage: "dumbbell.fill")
                }
                .tag(AppTab.muscuLog)
            
            LogBookTabView()
                .tabItem {
                    Label("LogBook", systemImage: "book.fill")
                }
                .tag(AppTab.logBook)

            MealTabView()
                .tabItem {
                    Label("Repas", systemImage: "carrot.fill")
                }
                .tag(AppTab.repas)

            NavigationStack {
                ChillHomeView()
            }
            .tabItem {
                Label("Chill", systemImage: "wind")
            }
            .tag(AppTab.chill)

        }
        .tint(.accentColor)
        .environment(\.openNexoraSettings) { showingSettings = true }
        .sheet(isPresented: $showingSettings) {
            NexoraSettingsView()
                .presentationDetents([.large])
        }
        .runtimeLayoutDiagnostics("AppCoordinator TabView")
    }
}

struct MuscuLogTabView: View {
    var body: some View {
        NavigationStack {
            MuscuLogContentView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NexoraSettingsToolbarButton()
                    }
                }
        }
    }
}

struct LogBookTabView: View {
    var body: some View {
        NavigationStack {
            LogBookView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NexoraSettingsToolbarButton()
                    }
                }
        }
    }
}

struct MuscuLogContentView: View {
    @State private var selectedSection: MuscuLogSection = .home
    
    enum MuscuLogSection: String, CaseIterable, Identifiable {
        case home = "Accueil"
        case history = "Historique"
        case progression = "Progression"
        case settings = "Réglages"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .history: return "clock.fill"
            case .progression: return "chart.xyaxis.line"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                ForEach(MuscuLogSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, NexoraSpacing.md)
            .padding(.vertical, NexoraSpacing.sm)
            .background(NexoraColors.groupedBackground)
            
            Group {
                switch selectedSection {
                case .home:
                    MuscuLogHomeContent()
                case .history:
                    MuscuLogHistoryContent()
                case .progression:
                    MuscuLogProgressionContent()
                case .settings:
                    MuscuLogSettingsContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("MuscuLog")
        .navigationBarTitleDisplayMode(.large)
        .background(NexoraColors.groupedBackground)
    }
}
