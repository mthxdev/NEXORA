import SwiftUI
import SwiftData

struct SeriesDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var series: SeriesEntry
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(series.title)
                            .font(NexoraTypography.title2)
                        if let year = series.firstAirYear {
                            Text("\(year)")
                                .font(NexoraTypography.subheadline)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }
                    
                    Spacer()
                    
                    if series.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Section("Statut et progression") {
                Picker("Statut", selection: $series.status) {
                    ForEach(SeriesStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                if series.status == .completed, let date = series.dateCompleted {
                    HStack {
                        Text("Terminée le")
                        Spacer()
                        Text(date.formatted(date: .long, time: .omitted))
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
                
                VStack(spacing: NexoraSpacing.md) {
                    HStack {
                        Text("Saison \(series.currentSeason)")
                        Spacer()
                        if let total = series.totalSeasons {
                            Text("/ \(total) saisons")
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }
                    
                    ProgressView(value: series.progressPercentage)
                        .tint(.blue)
                    
                    HStack {
                        Text("Épisode \(series.currentEpisode)")
                        Spacer()
                        if let total = series.totalEpisodes {
                            Text("/ \(total) épisodes")
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }
                    
                    if series.progressPercentage > 0 && series.progressPercentage < 1 {
                        Text("\(Int(series.progressPercentage * 100))% complété")
                            .font(NexoraTypography.caption)
                            .foregroundStyle(NexoraColors.secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, NexoraSpacing.xs)
            }
            
            if !series.seriesDescription.isEmpty {
                Section("Description") {
                    Text(series.seriesDescription)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section("Note et avis") {
                RatingDisplay(rating: series.personalRating)
                
                if let comment = series.personalComment, !comment.isEmpty {
                    Text(comment)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section {
                Toggle("Favori", isOn: $series.isFavorite)
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
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditSeriesView(series: series)
        }
        .alert("Supprimer cette série ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                modelContext.delete(series)
                dismiss()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
    }
}

struct EditSeriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var series: SeriesEntry
    
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
    
    init(series: SeriesEntry) {
        self.series = series
        _title = State(initialValue: series.title)
        _description = State(initialValue: series.seriesDescription)
        _status = State(initialValue: series.status)
        _currentSeason = State(initialValue: series.currentSeason)
        _currentEpisode = State(initialValue: series.currentEpisode)
        _totalSeasons = State(initialValue: series.totalSeasons)
        _totalEpisodes = State(initialValue: series.totalEpisodes)
        _rating = State(initialValue: series.personalRating)
        _comment = State(initialValue: series.personalComment ?? "")
        _isFavorite = State(initialValue: series.isFavorite)
        _firstAirYear = State(initialValue: series.firstAirYear)
        _dateCompleted = State(initialValue: series.dateCompleted)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField("Titre", text: $title)
                    TextField("Description (optionnel)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
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
                    ), in: 1950...Calendar.current.component(.year, from: Date()))
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
        series.title = title.trimmingCharacters(in: .whitespaces)
        series.seriesDescription = description
        series.status = status
        series.currentSeason = currentSeason
        series.currentEpisode = currentEpisode
        series.totalSeasons = totalSeasons
        series.totalEpisodes = totalEpisodes
        series.personalRating = rating
        series.personalComment = comment.isEmpty ? nil : comment
        series.isFavorite = isFavorite
        series.firstAirYear = firstAirYear
        series.dateCompleted = (status == .completed) ? dateCompleted : nil
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SeriesDetailView(series: SeriesEntry(
            title: "Breaking Bad",
            description: "Un professeur de chimie devient dealer de méthamphétamine",
            status: .inProgress,
            currentSeason: 3,
            currentEpisode: 7,
            totalSeasons: 5,
            totalEpisodes: 62,
            personalRating: 10,
            personalComment: "Meilleure série de tous les temps",
            isFavorite: true,
            firstAirYear: 2008
        ))
    }
    .modelContainer(for: SeriesEntry.self, inMemory: true)
}