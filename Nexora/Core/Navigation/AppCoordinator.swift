import SwiftUI

enum AppTab: Hashable {
    case home
    case muscuLog
    case logBook
    case settings
}

struct AppCoordinator: View {
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }
                .tag(AppTab.home)
            
            MuscuLogTabView()
                .tabItem {
                    Label("MuscuLog", systemImage: "dumbbell.fill")
                }
                .tag(AppTab.muscuLog)
            
            LogBookView()
                .tabItem {
                    Label("LogBook", systemImage: "book.fill")
                }
                .tag(AppTab.logBook)
            
            NexoraSettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(.accentColor)
    }
}

struct MuscuLogTabView: View {
    var body: some View {
        NavigationStack {
            MuscuLogContentView()
        }
    }
}

struct MuscuLogContentView: View {
    @State private var selectedTab: MuscuLogTab = .home
    
    enum MuscuLogTab: Hashable {
        case home
        case history
        case progression
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }
                .tag(MuscuLogTab.home)
            
            HistoryView()
                .tabItem {
                    Label("Historique", systemImage: "clock.fill")
                }
                .tag(MuscuLogTab.history)
            
            ProgressionView()
                .tabItem {
                    Label("Progression", systemImage: "chart.xyaxis.line")
                }
                .tag(MuscuLogTab.progression)
            
            MuscuLogSettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape.fill")
                }
                .tag(MuscuLogTab.settings)
        }
        .navigationTitle("MuscuLog")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct MuscuLogSettingsView: View {
    var body: some View {
        SettingsView()
            .navigationTitle("Réglages MuscuLog")
            .navigationBarTitleDisplayMode(.inline)
    }
}