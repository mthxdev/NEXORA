import SwiftUI
import SwiftData

struct AnimeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var anime: AnimeEntry
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(anime.title)
                            .font(NexoraTypography.title2)
                        if let year = anime.firstAirYear {
                            Text("\(year)")
                                .font(NexoraTypography.subheadline)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                        if anime.isMovie {
                            Label("Film", systemImage: "film.fill")
                                .font(.caption)
                                .foregroundStyle(.pink)
                        }
                    }
                    
                    Spacer()
                    
                    if anime.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Section("Statut et progression") {
                Picker("Statut", selection: $anime.status) {
                    ForEach(SeriesStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                if anime.status == .completed, let date = anime.dateCompleted {
                    HStack {
                        Text("Terminé le")
                        Spacer()
                        Text(date.formatted(date: .long, time: .omitted))
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
                
                VStack(spacing: NexoraSpacing.md) {
                    HStack {
                        Text("Saison \(anime.currentSeason)")
                        Spacer()
                        if let total = anime.totalSeasons {
                            Text("/ \(total) saisons")
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }
                    
                    ProgressView(value: anime.progressPercentage)
                        .tint(.pink)
                    
                    HStack {
                        Text("Épisode \(anime.currentEpisode)")
                        Spacer()
                        if let total = anime.totalEpisodes {
                            Text("/ \(total) épisodes")
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }
                    
                    if anime.progressPercentage > 0 && anime.progressPercentage < 1 {
                        Text("\(Int(anime.progressPercentage * 100))% complété")
                            .font(NexoraTypography.caption)
                            .foregroundStyle(NexoraColors.secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, NexoraSpacing.xs)
            }
            
            if !anime.animeDescription.isEmpty {
                Section("Description") {
                    Text(anime.animeDescription)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section("Note et avis") {
                RatingDisplay(rating: anime.personalRating)
                
                if let comment = anime.personalComment, !comment.isEmpty {
                    Text(comment)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section {
                Toggle("Favori", isOn: $anime.isFavorite)
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Supprimer", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(anime.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditAnimeView(anime: anime)
        }
        .alert("Supprimer cet animé ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                modelContext.delete(anime)
                dismiss()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
    }
}

struct EditAnimeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var anime: AnimeEntry
    
    @State private var title: String
    @State private var description: String
    @State private var status: SeriesStatus
    @State private var currentSeason: Int
    @State private var currentEpisode: Int
    @State private var totalSeasons: Int?
    @State private var totalEpisodes: Int?
    @State private var rating: Int?
    @State private var comment: String
    @State private var isFavorite: Bool
    @State private var firstAirYear: Int?
    @State private var dateCompleted: Date?
    @State private var isMovie: Bool
    
    init(anime: AnimeEntry) {
        self.anime = anime
        _title = State(initialValue: anime.title)
        _description = State(initialValue: anime.animeDescription)
        _status = State(initialValue: anime.status)
        _currentSeason = State(initialValue: anime.currentSeason)
        _currentEpisode = State(initialValue: anime.currentEpisode)
        _totalSeasons = State(initialValue: anime.totalSeasons)
        _totalEpisodes = State(initialValue: anime.totalEpisodes)
        _rating = State(initialValue: anime.personalRating)
        _comment = State(initialValue: anime.personalComment ?? "")
        _isFavorite = State(initialValue: anime.isFavorite)
        _firstAirYear = State(initialValue: anime.firstAirYear)
        _dateCompleted = State(initialValue: anime.dateCompleted)
        _isMovie = State(initialValue: anime.isMovie)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField("Titre", text: $title)
                    TextField("Description (optionnel)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("C'est un film", isOn: $isMovie)
                }
                
                Section("Statut et progression") {
                    Picker("Statut", selection: $status) {
                        ForEach(SeriesStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }
                    
                    if status == .completed {
                        DatePicker("Date de fin", selection: Binding(
                            get: { dateCompleted ?? Date() },
                            set: { dateCompleted = $0 }
                        ), displayedComponents: .date)
                    }
                    
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
                    
                    Stepper("Année de diffusion: \(firstAirYear ?? 0)", value: Binding(
                        get: { firstAirYear ?? 0 },
                        set: { firstAirYear = $0 > 0 ? $0 : nil }
                    ), in: 1960...Calendar.current.component(.year, from: Date()))
                }
                
                Section("Note et avis") {
                    RatingPicker(rating: $rating)
                    TextField("Commentaire (optionnel)", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Toggle("Favori", isOn: $isFavorite)
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func save() {
        anime.title = title.trimmingCharacters(in: .whitespaces)
        anime.animeDescription = description
        anime.status = status
        anime.currentSeason = currentSeason
        anime.currentEpisode = currentEpisode
        anime.totalSeasons = totalSeasons
        anime.totalEpisodes = totalEpisodes
        anime.personalRating = rating
        anime.personalComment = comment.isEmpty ? nil : comment
        anime.isFavorite = isFavorite
        anime.firstAirYear = firstAirYear
        anime.dateCompleted = (status == .completed) ? dateCompleted : nil
        anime.isMovie = isMovie
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AnimeDetailView(anime: AnimeEntry(
            title: "Attack on Titan",
            description: "L'humanité lutte contre des titans",
            status: .completed,
            currentSeason: 4,
            currentEpisode: 28,
            totalSeasons: 4,
            totalEpisodes: 87,
            personalRating: 10,
            personalComment: "Chef-d'œuvre absolu",
            isFavorite: true,
            firstAirYear: 2013
        ))
    }
    .modelContainer(for: AnimeEntry.self, inMemory: true)
}