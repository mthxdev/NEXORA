import SwiftUI
import SwiftData

struct LearningDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var learning: LearningEntry
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(learning.name)
                            .font(NexoraTypography.title2)
                        
                        Label(learning.status.rawValue, systemImage: learning.status.icon)
                            .font(.caption)
                            .foregroundStyle(statusColor(learning.status))
                    }
                    
                    Spacer()
                    
                    if learning.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Section("Statut") {
                Picker("Statut", selection: $learning.status) {
                    ForEach(LearningStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                
                if learning.status == .completed, let date = learning.dateCompleted {
                    HStack {
                        Text("Terminé le")
                        Spacer()
                        Text(date.formatted(date: .long, time: .omitted))
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
                
                if let started = learning.dateStarted {
                    HStack {
                        Text("Commencé le")
                        Spacer()
                        Text(started.formatted(date: .long, time: .omitted))
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
                
                HStack {
                    Text("Dernière mise à jour")
                    Spacer()
                    Text(learning.dateLastUpdated.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            if !learning.learningDescription.isEmpty {
                Section("Description") {
                    Text(learning.learningDescription)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            if !learning.goal.isEmpty {
                Section("Objectif") {
                    Text(learning.goal)
                        .foregroundStyle(.blue)
                }
            }
            
            if !learning.notes.isEmpty {
                Section("Notes") {
                    Text(learning.notes)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            if !learning.resources.isEmpty {
                Section("Ressources") {
                    Text(learning.resources)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section {
                Toggle("Favori", isOn: $learning.isFavorite)
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
        .navigationTitle(learning.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditLearningView(learning: learning)
        }
        .alert("Supprimer cet apprentissage ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                modelContext.delete(learning)
                dismiss()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
    }
    
    private func statusColor(_ status: LearningStatus) -> Color {
        switch status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .paused: return .orange
        }
    }
}

struct EditLearningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var learning: LearningEntry
    
    @State private var name: String
    @State private var description: String
    @State private var status: LearningStatus
    @State private var dateStarted: Date?
    @State private var dateCompleted: Date?
    @State private var goal: String
    @State private var notes: String
    @State private var resources: String
    @State private var isFavorite: Bool
    
    init(learning: LearningEntry) {
        self.learning = learning
        _name = State(initialValue: learning.name)
        _description = State(initialValue: learning.learningDescription)
        _status = State(initialValue: learning.status)
        _dateStarted = State(initialValue: learning.dateStarted)
        _dateCompleted = State(initialValue: learning.dateCompleted)
        _goal = State(initialValue: learning.goal)
        _notes = State(initialValue: learning.notes)
        _resources = State(initialValue: learning.resources)
        _isFavorite = State(initialValue: learning.isFavorite)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField("Nom", text: $name)
                    TextField("Description (optionnel)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Statut") {
                    Picker("Statut", selection: $status) {
                        ForEach(LearningStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }
                    
                    if status == .completed {
                        DatePicker("Date de fin", selection: Binding(
                            get: { dateCompleted ?? Date() },
                            set: { dateCompleted = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    DatePicker("Date de début", selection: Binding(
                        get: { dateStarted ?? Date() },
                        set: { dateStarted = $0 }
                    ), displayedComponents: .date)
                }
                
                Section("Détails (optionnel)") {
                    TextField("Objectif", text: $goal)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Ressources (liens, livres, cours...)", text: $resources, axis: .vertical)
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
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func save() {
        learning.name = name.trimmingCharacters(in: .whitespaces)
        learning.learningDescription = description
        learning.status = status
        learning.dateStarted = dateStarted
        learning.dateCompleted = (status == .completed) ? dateCompleted : nil
        learning.goal = goal
        learning.notes = notes
        learning.resources = resources
        learning.isFavorite = isFavorite
        learning.dateLastUpdated = Date()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        LearningDetailView(learning: LearningEntry(
            name: "SwiftUI avancé",
            description: "Maîtriser les animations et layouts complexes",
            status: .inProgress,
            dateStarted: Date().addingTimeInterval(-86400 * 30),
            goal: "Pouvoir créer des apps professionnelles",
            notes: "Étudier GeometryReader, Canvas, TimelineView",
            resources: "Apple Developer Docs, Hacking with Swift, PointFree",
            isFavorite: true
        ))
    }
    .modelContainer(for: LearningEntry.self, inMemory: true)
}