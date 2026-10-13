import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var project: ProjectEntry
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(NexoraTypography.title2)
                        
                        HStack(spacing: 8) {
                            Label(project.status.rawValue, systemImage: project.status.icon)
                                .font(.caption)
                                .foregroundStyle(statusColor(project.status))
                            
                            Text("·")
                                .foregroundStyle(NexoraColors.tertiaryLabel)
                            
                            Label(project.priority.rawValue, systemImage: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(priorityColor(project.priority))
                        }
                    }
                    
                    Spacer()
                    
                    if project.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Section("Statut") {
                Picker("Statut", selection: $project.status) {
                    ForEach(ProjectStatus.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                
                if project.status == .completed, let date = project.dateCompleted {
                    HStack {
                        Text("Terminé le")
                        Spacer()
                        Text(date.formatted(date: .long, time: .omitted))
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
                
                Picker("Priorité", selection: $project.priority) {
                    ForEach(Priority.allCases) { p in
                        Label(p.rawValue, systemImage: "flag.fill").tag(p)
                    }
                }
            }
            
            if !project.projectDescription.isEmpty {
                Section("Description") {
                    Text(project.projectDescription)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            if let goal = project.goal, !goal.isEmpty {
                Section("Objectif") {
                    Text(goal)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            if let nextStep = project.nextStep, !nextStep.isEmpty {
                Section("Prochaine étape") {
                    Text(nextStep)
                        .foregroundStyle(.blue)
                }
            }
            
            if !project.notes.isEmpty {
                Section("Notes") {
                    Text(project.notes)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section("Informations") {
                HStack {
                    Text("Créé le")
                    Spacer()
                    Text(project.dateCreated.formatted(date: .long, time: .shortened))
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
                
                HStack {
                    Text("Modifié le")
                    Spacer()
                    Text(project.dateModified.formatted(date: .long, time: .shortened))
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            
            Section {
                Toggle("Favori", isOn: $project.isFavorite)
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
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditProjectView(project: project)
        }
        .alert("Supprimer ce projet ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                modelContext.delete(project)
                dismiss()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
    }
    
    private func statusColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .planning: return .gray
        case .active: return .blue
        case .onHold: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct EditProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var project: ProjectEntry
    
    @State private var name: String
    @State private var description: String
    @State private var status: ProjectStatus
    @State private var priority: Priority
    @State private var goal: String
    @State private var nextStep: String
    @State private var notes: String
    @State private var isFavorite: Bool
    
    init(project: ProjectEntry) {
        self.project = project
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.projectDescription)
        _status = State(initialValue: project.status)
        _priority = State(initialValue: project.priority)
        _goal = State(initialValue: project.goal ?? "")
        _nextStep = State(initialValue: project.nextStep ?? "")
        _notes = State(initialValue: project.notes)
        _isFavorite = State(initialValue: project.isFavorite)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField("Nom du projet", text: $name)
                    TextField("Description (optionnel)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Statut et priorité") {
                    Picker("Statut", selection: $status) {
                        ForEach(ProjectStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }
                    
                    Picker("Priorité", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }
                
                Section("Détails (optionnel)") {
                    TextField("Objectif principal", text: $goal)
                    TextField("Prochaine étape", text: $nextStep)
                    TextField("Notes", text: $notes, axis: .vertical)
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
        project.name = name.trimmingCharacters(in: .whitespaces)
        project.projectDescription = description
        project.status = status
        project.priority = priority
        project.goal = goal.isEmpty ? nil : goal
        project.nextStep = nextStep.isEmpty ? nil : nextStep
        project.notes = notes
        project.isFavorite = isFavorite
        project.dateModified = Date()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: ProjectEntry(
            name: "Refonte site web",
            description: "Moderniser le site personnel",
            status: .active,
            priority: .high,
            goal: "Lancer avant fin d'année",
            nextStep: "Choisir la stack technique",
            notes: "Regarder Next.js vs Astro",
            isFavorite: true
        ))
    }
    .modelContainer(for: ProjectEntry.self, inMemory: true)
}