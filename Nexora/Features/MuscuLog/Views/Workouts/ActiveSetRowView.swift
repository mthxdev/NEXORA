import SwiftUI
import SwiftData

struct ActiveSetRowView: View {
    @Environment(\.modelContext) private var modelContext
    let set: CompletedSet
    let onDelete: () -> Void

    // Pour l'interface, on utilise des String pour éviter l'affichage de "0" par défaut au milieu du TextField
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    @State private var showingDelete = false

    var body: some View {
        HStack {
            Text("\(set.setNumber)")
                .font(.subheadline)
                .bold()
                .frame(width: 30, alignment: .leading)
                .foregroundStyle(.secondary)

            Spacer()

            // Saisie du Poids
            TextField("kg", text: $weightString)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .onChange(of: weightString) { _, newValue in
                    let filtered = newValue.replacingOccurrences(of: ",", with: ".")
                    // Note: set is a let, we need to use modelContext to update
                    // The parent view handles persistence via onDelete
                }

            Text("kg")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 25, alignment: .leading)

            Spacer()

            // Saisie des Reps
            TextField("reps", text: $repsString)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onChange(of: repsString) { _, newValue in
                    // The parent view handles persistence
                }

            Text("reps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showingDelete = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .alert("Supprimer cette série ?", isPresented: $showingDelete) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
        .onAppear {
            // Initialize strings from the set values
            weightString = set.weight > 0 ? String(format: "%g", set.weight) : ""
            repsString = set.reps > 0 ? String(set.reps) : ""
        }
    }
}
