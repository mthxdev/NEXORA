import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var game: GameEntry
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title)
                            .font(NexoraTypography.title2)
                        if !game.platform.isEmpty {
                            Text(game.platform)
                                .font(NexoraTypography.subheadline)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                        if let year = game.releaseYear {
                            Text("\(year)")
                                .font(NexoraTypography.subheadline)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }
                    
                    Spacer()
                    
                    if game.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Section("Statut") {
                Picker("Statut", selection: $game.status) {
                    ForEach(MediaStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                if game.status == .completed, let date = game.dateCompleted {
                    HStack {
                        Text("Terminé le")
                        Spacer()
                        Text(date.formatted(date: .long, time: .omitted))
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
            }
            
            if !game.gameDescription.isEmpty {
                Section("Description") {
                    Text(game.gameDescription)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            if let hours = game.playtimeHours, hours > 0 {
                Section("Temps de jeu") {
                    HStack {
                        Text("\(String(format: "%.1f", hours)) heures")
                            .font(NexoraTypography.headline)
                        Spacer()
                    }
                }
            }
            
            Section("Note et avis") {
                RatingDisplay(rating: game.personalRating)
                
                if let comment = game.personalComment, !comment.isEmpty {
                    Text(comment)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section {
                Toggle("Favori", isOn: $game.isFavorite)
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
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditGameView(game: game)
        }
        .alert("Supprimer ce jeu ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                modelContext.delete(game)
                dismiss()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
    }
}

struct EditGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var game: GameEntry
    
    @State private var title: String
    @State private var description: String
    @State private var platform: String
    @State private var status: MediaStatus
    @State private var dateCompleted: Date?
    @State private var rating: Int?
    @State private var comment: String
    @State private var isFavorite: Bool
    @State private var releaseYear: Int?
    @State private var playtimeHours: Double?
    
    init(game: GameEntry) {
        self.game = game
        _title = State(initialValue: game.title)
        _description = State(initialValue: game.gameDescription)
        _platform = State(initialValue: game.platform)
        _status = State(initialValue: game.status)
        _dateCompleted = State(initialValue: game.dateCompleted)
        _rating = State(initialValue: game.personalRating)
        _comment = State(initialValue: game.personalComment ?? "")
        _isFavorite = State(initialValue: game.isFavorite)
        _releaseYear = State(initialValue: game.releaseYear)
        _playtimeHours = State(initialValue: game.playtimeHours)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField("Titre", text: $title)
                    TextField("Plateforme (ex: PS5, Switch, PC)", text: $platform)
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
                        DatePicker("Date de fin", selection: Binding(
                            get: { dateCompleted ?? Date() },
                            set: { dateCompleted = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    Stepper("Temps de jeu: \(playtimeString)", value: Binding(
                        get: { Int(playtimeHours ?? 0) },
                        set: { playtimeHours = Double($0) }
                    ), in: 0...1000)
                    
                    Stepper("Année de sortie: \(releaseYear ?? 0)", value: Binding(
                        get: { releaseYear ?? 0 },
                        set: { releaseYear = $0 > 0 ? $0 : nil }
                    ), in: 1970...Calendar.current.component(.year, from: Date()))
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
    
    private var playtimeString: String {
        if let hours = playtimeHours {
            return String(format: "%.1fh", hours)
        }
        return "0h"
    }
    
    private func save() {
        game.title = title.trimmingCharacters(in: .whitespaces)
        game.platform = platform
        game.gameDescription = description
        game.status = status
        game.dateCompleted = (status == .completed) ? dateCompleted : nil
        game.personalRating = rating
        game.personalComment = comment.isEmpty ? nil : comment
        game.isFavorite = isFavorite
        game.releaseYear = releaseYear
        game.playtimeHours = playtimeHours
        dismiss()
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: GameEntry(
            title: "The Witcher 3",
            description: "RPG en monde ouvert",
            platform: "PC",
            status: .completed,
            dateCompleted: Date(),
            personalRating: 10,
            personalComment: "Meilleur RPG",
            isFavorite: true,
            releaseYear: 2015,
            playtimeHours: 120.5
        ))
    }
    .modelContainer(for: GameEntry.self, inMemory: true)
}