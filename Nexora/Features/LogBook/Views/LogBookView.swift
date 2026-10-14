import SwiftUI
import SwiftData

struct LogBookView: View {
    @State private var searchText = ""
    @State private var selectedCategory: LogBookCategory = .movie
    @State private var showingAddEntry = false
    
    @Query(sort: \MovieEntry.dateAdded, order: .reverse) private var movies: [MovieEntry]
    @Query(sort: \SeriesEntry.dateAdded, order: .reverse) private var series: [SeriesEntry]
    @Query(sort: \AnimeEntry.dateAdded, order: .reverse) private var animes: [AnimeEntry]
    @Query(sort: \GameEntry.dateAdded, order: .reverse) private var games: [GameEntry]
    @Query(sort: \ProjectEntry.dateModified, order: .reverse) private var projects: [ProjectEntry]
    @Query(sort: \LearningEntry.dateLastUpdated, order: .reverse) private var learnings: [LearningEntry]
    
    private var filteredMovies: [MovieEntry] {
        if searchText.isEmpty { return movies }
        return movies.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredSeries: [SeriesEntry] {
        if searchText.isEmpty { return series }
        return series.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredAnimes: [AnimeEntry] {
        if searchText.isEmpty { return animes }
        return animes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredGames: [GameEntry] {
        if searchText.isEmpty { return games }
        return games.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredProjects: [ProjectEntry] {
        if searchText.isEmpty { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredLearnings: [LearningEntry] {
        if searchText.isEmpty { return learnings }
        return learnings.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var currentEntriesCount: Int {
        switch selectedCategory {
        case .movie: return filteredMovies.count
        case .series: return filteredSeries.count
        case .anime: return filteredAnimes.count
        case .game: return filteredGames.count
        case .project: return filteredProjects.count
        case .learning: return filteredLearnings.count
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Rechercher dans \(selectedCategory.rawValue)...")
                    .padding(.horizontal, NexoraSpacing.md)
                    .padding(.vertical, NexoraSpacing.sm)
                    .background(NexoraColors.groupedBackground)
                
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NexoraSpacing.sm) {
                        ForEach(LogBookCategory.allCases, id: \.self) { category in
                            CategoryTabButton(
                                category: category,
                                isSelected: selectedCategory == category,
                                count: countForCategory(category)
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, NexoraSpacing.md)
                }
                .padding(.vertical, NexoraSpacing.sm)
                .background(NexoraColors.groupedBackground)
                
                Divider()
                    .padding(.horizontal, -NexoraSpacing.md)
                
                // Content list
                Group {
                    if currentEntriesCount == 0 {
                        emptyStateView
                    } else {
                        listView
                    }
                }
            }
            .navigationTitle("LogBook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView(category: selectedCategory)
            }
            .background(NexoraColors.groupedBackground)
        }
    }
    
    private func countForCategory(_ category: LogBookCategory) -> Int {
        switch category {
        case .movie: return movies.count
        case .series: return series.count
        case .anime: return animes.count
        case .game: return games.count
        case .project: return projects.count
        case .learning: return learnings.count
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: NexoraSpacing.lg) {
            Image(systemName: selectedCategory.icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(NexoraColors.tertiaryLabel)
            
            VStack(spacing: NexoraSpacing.xs) {
                Text("Aucun \(selectedCategory.rawValue.lowercased())")
                    .font(NexoraTypography.title3)
                    .foregroundStyle(NexoraColors.label)
                
                Text(emptyStateDescription)
                    .font(NexoraTypography.subheadline)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, NexoraSpacing.xl)
            
            Button {
                showingAddEntry = true
            } label: {
                Label("Ajouter", systemImage: "plus")
                    .primaryButton()
            }
            .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(NexoraSpacing.xl)
    }
    
    private var emptyStateDescription: String {
        switch selectedCategory {
        case .movie: return "Ajoute ton premier film à voir ou déjà vu."
        case .series: return "Suis tes séries préférées, épisode par épisode."
        case .anime: return "Organise tes animés et mangas."
        case .game: return "Gère ton backlog de jeux vidéo."
        case .project: return "Planifie et suis tes projets personnels."
        case .learning: return "Note tes apprentissages et compétences."
        }
    }
    
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: NexoraSpacing.sm) {
                switch selectedCategory {
                case .movie:
                    ForEach(filteredMovies) { movie in
                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                            LogBookRow(title: movie.title, status: movie.status, dateAdded: movie.dateAdded, isFavorite: movie.isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                case .series:
                    ForEach(filteredSeries) { series in
                        NavigationLink(destination: SeriesDetailView(series: series)) {
                            LogBookRow(title: series.title, status: series.status, dateAdded: series.dateAdded, isFavorite: series.isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                case .anime:
                    ForEach(filteredAnimes) { anime in
                        NavigationLink(destination: AnimeDetailView(anime: anime)) {
                            LogBookRow(title: anime.title, status: anime.status, dateAdded: anime.dateAdded, isFavorite: anime.isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                case .game:
                    ForEach(filteredGames) { game in
                        NavigationLink(destination: GameDetailView(game: game)) {
                            LogBookRow(title: game.title, status: game.status, dateAdded: game.dateAdded, isFavorite: game.isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                case .project:
                    ForEach(filteredProjects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            LogBookRow(title: project.name, status: project.status, dateAdded: project.dateCreated, isFavorite: project.isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                case .learning:
                    ForEach(filteredLearnings) { learning in
                        NavigationLink(destination: LearningDetailView(learning: learning)) {
                            LogBookRow(title: learning.name, status: learning.status, dateAdded: learning.dateLastUpdated, isFavorite: learning.isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, NexoraSpacing.md)
            .padding(.vertical, NexoraSpacing.sm)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(NexoraColors.tertiaryLabel)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(NexoraColors.tertiaryLabel)
                }
            }
        }
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
    }
}

struct CategoryTabButton: View {
    let category: LogBookCategory
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: NexoraSpacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                Text(category.rawValue)
                    .font(NexoraTypography.subheadline.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(NexoraTypography.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : NexoraColors.cardBackground)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, NexoraSpacing.md)
            .padding(.vertical, NexoraSpacing.sm)
            .foregroundStyle(isSelected ? .white : categoryColor(category))
            .background(isSelected ? categoryColor(category) : categoryColor(category).opacity(0.15))
            .clipShape(Capsule())
        }
    }
    
    private func categoryColor(_ category: LogBookCategory) -> Color {
        switch category.color {
        case "red": return .red
        case "blue": return .blue
        case "pink": return .pink
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        default: return .accentColor
        }
    }
}

struct LogBookRow: View {
    let title: String
    let status: any RawRepresentable<String>
    let dateAdded: Date
    let isFavorite: Bool
    
    var body: some View {
        HStack(spacing: NexoraSpacing.md) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                HStack {
                    Text(title)
                        .font(NexoraTypography.body)
                        .foregroundStyle(NexoraColors.label)
                        .lineLimit(1)
                    
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                
                HStack(spacing: NexoraSpacing.sm) {
                    Label(statusText, systemImage: statusIcon)
                        .font(NexoraTypography.caption)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                    
                    Text(dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .font(NexoraTypography.caption)
                        .foregroundStyle(NexoraColors.tertiaryLabel)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(NexoraColors.tertiaryLabel)
        }
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
    }
    
    private var statusText: String { status.rawValue }
    private var statusIcon: String {
        if let s = status as? MediaStatus { return s.icon }
        if let s = status as? SeriesStatus { return s.icon }
        if let s = status as? ProjectStatus { return s.icon }
        if let s = status as? LearningStatus { return s.icon }
        return "circle"
    }
    
    private var statusColor: Color {
        if let s = status as? MediaStatus {
            switch s {
            case .toWatch: return .gray
            case .inProgress: return .blue
            case .completed: return .green
            case .abandoned: return .red
            }
        } else if let s = status as? SeriesStatus {
            switch s {
            case .toStart: return .gray
            case .inProgress: return .blue
            case .completed: return .green
            case .abandoned: return .red
            }
        } else if let s = status as? ProjectStatus {
            switch s {
            case .planning: return .gray
            case .active: return .blue
            case .onHold: return .orange
            case .completed: return .green
            case .cancelled: return .red
            }
        } else if let s = status as? LearningStatus {
            switch s {
            case .notStarted: return .gray
            case .inProgress: return .blue
            case .completed: return .green
            case .paused: return .orange
            }
        }
        return .gray
    }
}

#Preview {
    LogBookView()
        .modelContainer(for: [MovieEntry.self, SeriesEntry.self, AnimeEntry.self, GameEntry.self, ProjectEntry.self, LearningEntry.self], inMemory: true)
}