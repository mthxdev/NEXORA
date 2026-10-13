import SwiftUI
import SwiftData

struct ProgramFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var program: Program?

    @State private var name: String = ""

    var isEditing: Bool { program != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom du programme", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Nom")
                } footer: {
                    Text("Exemple : Upper/Lower, Full Body, PPL…")
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouveau programme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Enregistrer" : "Créer") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let program {
                    name = program.name
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let program {
            program.name = trimmedName
        } else {
            let newProgram = Program(name: trimmedName)
            modelContext.insert(newProgram)
        }
        dismiss()
    }
}

#Preview("Créer") {
    ProgramFormView()
        .modelContainer(for: Program.self, inMemory: true)
}

#Preview("Modifier") {
    let program = Program(name: "Upper/Lower")
    return ProgramFormView(program: program)
        .modelContainer(for: Program.self, inMemory: true)
}
