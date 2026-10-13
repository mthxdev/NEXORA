import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let category: LogBookCategory
    
    @State private var title = ""
    @State private var description = ""
    @State private var status: Any?
    @State private var rating: Int?
    @State private var comment = ""
    @State private var isFavorite = false
    
    // Category-specific fields
    @State private var dateWatched: Date?
    @State private var platform = ""
    @State private var releaseYear: Int?
    @State private var currentSeason = 1
    @State private var currentEpisode = 0
    @State private var totalSeasons: Int?
    @State private var totalEpisodes: Int?
    @State private var priority: Priority = .medium
    @State private var goal = ""
    @State private var nextStep = ""
    @State private var notes = ""
    @State private var resources = ""
    @State private var dateStarted: Date?
    
    private var selectedMediaStatus: MediaStatus {
        get { (status as? MediaStatus) ?? .toWatch }
        set { status = newValue }
    }
    
    private var selectedSeriesStatus: SeriesStatus {
        get { (status as? SeriesStatus) ?? .toStart }
        set { status = newValue }
    }
    
    private var selectedProjectStatus: ProjectStatus {
        get { (status as? ProjectStatus) ?? .planning }
        set { status = newValue }
    }
    
    private var selectedLearningStatus: LearningStatus {
        get { (status as? LearningStatus) ?? .notStarted }
        set { status = newValue }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField(titrePlaceholder, text: $title)
                    
                    TextField("Description (optionnel)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Statut") {
                    statusPicker
                }
                
                categorySpecificFields
                
                Section("Note et avis") {
                    RatingPicker(rating: $rating)
                    
                    TextField("Commentaire personnel (optionnel)", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Toggle("Favori", isOn: $isFavorite)
                }
            }
            .navigationTitle("Nouveau \(category.rawValue.dropLast())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                setupInitialStatus()
            }
        }
    }
    
    private var titrePlaceholder: String {
        switch category {
        case .movie: return "Titre du film"
        case .series: return "Titre de la série"
        case .anime: return "Titre de l'animé"
        case .game: return "Titre du jeu"
        case .project: return "Nom du projet"
        case .learning: return "Nom de l'apprentissage"
        }
    }
    
    private var statusPicker: some View {
        Group {
            switch category {
            case .movie, .game:
                Picker("Statut", selection: $selectedMediaStatus) {
                    ForEach(MediaStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
            case .series, .anime:
                Picker("Statut", selection: $selectedSeriesStatus) {
                    ForEach(SeriesStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
            case .project:
                Picker("Statut", selection: $selectedProjectStatus) {
                    ForEach(ProjectStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
            case .learning:
                Picker("Statut", selection: $selectedLearningStatus) {
                    ForEach(LearningStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
            }
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    private var categorySpecificFields: some View {
        switch category {
        case .movie:
            Section("Détails du film") {
                DatePicker("Date de visionnage", selection: Binding(
                    get: { dateWatched ?? Date() },
                    set: { dateWatched = $0 }
                ), displayedComponents: .date)
                
                Stepper("Année de sortie: \(releaseYear ?? 0)", value: Binding(
                    get: { releaseYear ?? 0 },
                    set: { releaseYear = $0 > 0 ? $0 : nil }
                ), in: 1880...Calendar.current.component(.year, from: Date()))
            }
            
        case .series, .anime:
            Section("Progression") {
                Stepper("Saison: \(currentSeason)", value: $currentSeason, in: 1...50)
                Stepper("Épisode: \(currentEpisode)", value: $currentEpisode, in: 0...100)
                
                Stepper("Total saisons: \(totalSeasons ?? 0)", value: Binding(
                    get: { totalSeasons ?? 0 },
                    set: { totalSeasons = $0 > 0 ? $0 : nil }
                ), in: 0...50)
                
                Stepper("Total épisodes: \(totalEpisodes ?? 0)", value: Binding(
                    get: { totalEpisodes ?? 0 },
                    set: { totalEpisodes = $0 > 0 ? $0 : nil }
                ), in: 0...500)
            }
            
            if category == .series {
                Section("Détails de la série") {
                    Stepper("Année de diffusion: \(releaseYear ?? 0)", value: Binding(
                        get: { releaseYear ?? 0 },
                        set: { releaseYear = $0 > 0 ? $0 : nil }
                    ), in: 1950...Calendar.current.component(.year, from: Date()))
                }
            } else {
                Section("Détails de l'animé") {
                    Stepper("Année de diffusion: \(releaseYear ?? 0)", value: Binding(
                        get: { releaseYear ?? 0 },
                        set: { releaseYear = $0 > 0 ? $0 : nil }
                    ), in: 1960...Calendar.current.component(.year, from: Date()))
                    
                    Toggle("C'est un film", isOn: Binding(
                        get: { false },
                        set: { _ in }
                    ))
                }
            }
            
        case .game:
            Section("Détails du jeu") {
                TextField("Plateforme (ex: PS5, Switch, PC)", text: $platform)
                
                DatePicker("Date de fin", selection: Binding(
                    get: { dateWatched ?? Date() },
                    set: { dateWatched = $0 }
                ), displayedComponents: .date)
                
                Stepper("Temps de jeu: \(playtimeString)", value: Binding(
                    get: { Int(playtimeHours ?? 0) },
                    set: { playtimeHours = Double($0) }
                ), in: 0...1000)
                
                Stepper("Année de sortie: \(releaseYear ?? 0)", value: Binding(
                    get: { releaseYear ?? 0 },
                    set: { releaseYear = $0 > 0 ? $0 : nil }
                ), in: 1970...Calendar.current.component(.year, from: Date()))
            }
            
        case .project:
            Section("Détails du projet") {
                Picker("Priorité", selection: $priority) {
                    ForEach(Priority.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                
                TextField("Objectif principal (optionnel)", text: $goal)
                TextField("Prochaine étape (optionnel)", text: $nextStep)
                TextField("Notes (optionnel)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            
        case .learning:
            Section("Détails de l'apprentissage") {
                DatePicker("Date de début", selection: Binding(
                    get: { dateStarted ?? Date() },
                    set: { dateStarted = $0 }
                ), displayedComponents: .date)
                
                TextField("Objectif (optionnel)", text: $goal)
                TextField("Notes (optionnel)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Ressources (optionnel)", text: $resources, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
    }
    
    private var playtimeString: String {
        if let hours = playtimeHours {
            return String(format: "%.1fh", hours)
        }
        return "0h"
    }
    
    private func setupInitialStatus() {
        switch category {
        case .movie, .game: status = MediaStatus.toWatch
        case .series, .anime: status = SeriesStatus.toStart
        case .project: status = ProjectStatus.planning
        case .learning: status = LearningStatus.notStarted
        }
    }
    
    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        switch category {
        case .movie:
            let entry = MovieEntry(
                title: trimmedTitle,
                description: description,
                status: selectedMediaStatus,
                dateWatched: dateWatched,
                personalRating: rating,
                personalComment: comment.isEmpty ? nil : comment,
                isFavorite: isFavorite,
                releaseYear: releaseYear
            )
            modelContext.insert(entry)
            
        case .series:
            let entry = SeriesEntry(
                title: trimmedTitle,
                description: description,
                status: selectedSeriesStatus,
                currentSeason: currentSeason,
                currentEpisode: currentEpisode,
                totalSeasons: totalSeasons,
                totalEpisodes: totalEpisodes,
                personalRating: rating,
                personalComment: comment.isEmpty ? nil : comment,
                isFavorite: isFavorite,
                firstAirYear: releaseYear
            )
            modelContext.insert(entry)
            
        case .anime:
            let entry = AnimeEntry(
                title: trimmedTitle,
                description: description,
                status: selectedSeriesStatus,
                currentSeason: currentSeason,
                currentEpisode: currentEpisode,
                totalSeasons: totalSeasons,
                totalEpisodes: totalEpisodes,
                personalRating: rating,
                personalComment: comment.isEmpty ? nil : comment,
                isFavorite: isFavorite,
                firstAirYear: releaseYear,
                isMovie: false
            )
            modelContext.insert(entry)
            
        case .game:
            let entry = GameEntry(
                title: trimmedTitle,
                description: description,
                platform: platform,
                status: selectedMediaStatus,
                dateCompleted: dateWatched,
                personalRating: rating,
                personalComment: comment.isEmpty ? nil : comment,
                isFavorite: isFavorite,
                releaseYear: releaseYear,
                playtimeHours: playtimeHours
            )
            modelContext.insert(entry)
            
        case .project:
            let entry = ProjectEntry(
                name: trimmedTitle,
                description: description,
                status: selectedProjectStatus,
                priority: priority,
                goal: goal.isEmpty ? nil : goal,
                nextStep: nextStep.isEmpty ? nil : nextStep,
                notes: notes,
                isFavorite: isFavorite
            )
            modelContext.insert(entry)
            
        case .learning:
            let entry = LearningEntry(
                name: trimmedTitle,
                description: description,
                status: selectedLearningStatus,
                dateStarted: dateStarted,
                goal: goal,
                notes: notes,
                resources: resources,
                isFavorite: isFavorite
            )
            modelContext.insert(entry)
        }
        
        dismiss()
    }
}

struct RatingPicker: View {
    @Binding var rating: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
            HStack {
                Text("Note personnelle")
                Spacer()
                if let rating {
                    Text("\(rating)/10")
                        .font(NexoraTypography.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                } else {
                    Text("Non noté")
                        .font(NexoraTypography.subheadline)
                        .foregroundStyle(NexoraColors.tertiaryLabel)
                }
            }
            
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { star in
                    Button {
                        rating = (rating == star) ? nil : star
                    } label: {
                        Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(star <= (rating ?? 0) ? .orange : NexoraColors.tertiaryLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    AddEntryView(category: .movie)
        .modelContainer(for: [MovieEntry.self], inMemory: true)
}