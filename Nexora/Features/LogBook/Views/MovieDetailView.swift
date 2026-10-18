import SwiftUI
import SwiftData

struct MovieDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var movie: MovieEntry
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(NexoraTypography.title2)
                        if let year = movie.releaseYear {
                            Text("\(year)")
                                .font(NexoraTypography.subheadline)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }
                    
                    Spacer()
                    
                    if movie.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Section("Statut") {
                Picker("Statut", selection: $movie.status) {
                    ForEach(MediaStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                if movie.status == .completed, let date = movie.dateWatched {
                    HStack {
                        Text("Vu le")
                        Spacer()
                        Text(date.formatted(date: .long, time: .omitted))
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
            }
            
            if !movie.movieDescription.isEmpty {
                Section("Description") {
                    Text(movie.movieDescription)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section("Note et avis") {
                RatingDisplay(rating: movie.personalRating)
                
                if let comment = movie.personalComment, !comment.isEmpty {
                    Text(comment)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section {
                Toggle("Favori", isOn: $movie.isFavorite)
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
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditMovieView(movie: movie)
        }
        .alert("Supprimer ce film ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                modelContext.delete(movie)
                dismiss()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
    }
}

struct EditMovieView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var movie: MovieEntry
    
    @State private var title: String
    @State private var description: String
    @State private var status: MediaStatus
    @State private var dateWatched: Date?
    @State private var rating: Int?
    @State private var comment: String
    @State private var isFavorite: Bool
    @State private var releaseYear: Int?
    
    init(movie: MovieEntry) {
        self.movie = movie
        _title = State(initialValue: movie.title)
        _description = State(initialValue: movie.movieDescription)
        _status = State(initialValue: movie.status)
        _dateWatched = State(initialValue: movie.dateWatched)
        _rating = State(initialValue: movie.personalRating)
        _comment = State(initialValue: movie.personalComment ?? "")
        _isFavorite = State(initialValue: movie.isFavorite)
        _releaseYear = State(initialValue: movie.releaseYear)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField("Titre", text: $title)
                    TextField("Description (optionnel)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Statut") {
                    Picker("Statut", selection: $status) {
                        ForEach(MediaStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }
                    
                    if status == .completed {
                        DatePicker("Date de visionnage", selection: Binding(
                            get: { dateWatched ?? Date() },
                            set: { dateWatched = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    Stepper("Année de sortie: \(releaseYear ?? 0)", value: Binding(
                        get: { releaseYear ?? 0 },
                        set: { releaseYear = $0 > 0 ? $0 : nil }
                    ), in: 1880...Calendar.current.component(.year, from: Date()))
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
        movie.title = title.trimmingCharacters(in: .whitespaces)
        movie.movieDescription = description
        movie.status = status
        movie.dateWatched = (status == .completed) ? dateWatched : nil
        movie.personalRating = rating
        movie.personalComment = comment.isEmpty ? nil : comment
        movie.isFavorite = isFavorite
        movie.releaseYear = releaseYear
        dismiss()
    }
}

struct RatingDisplay: View {
    let rating: Int?
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...10, id: \.self) { star in
                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(star <= (rating ?? 0) ? .orange : NexoraColors.tertiaryLabel)
            }
            
            if let rating {
                Text("\(rating)/10")
                    .font(NexoraTypography.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.leading, 8)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(movie: MovieEntry(
            title: "Inception",
            description: "Un film de Christopher Nolan",
            status: .completed,
            dateWatched: Date(),
            personalRating: 9,
            personalComment: "Excellent film",
            isFavorite: true,
            releaseYear: 2010
        ))
    }
    .modelContainer(for: MovieEntry.self, inMemory: true)
}