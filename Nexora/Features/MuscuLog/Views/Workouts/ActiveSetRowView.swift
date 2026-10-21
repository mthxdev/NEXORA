import SwiftUI

struct ActiveSetRowView: View {
    let setID: UUID
    let setNumber: Int
    let weight: Double
    let reps: Int
    let exerciseID: UUID
    let onDelete: (UUID) -> Void
    let onWeightChange: (UUID, Double) -> Void
    let onRepsChange: (UUID, Int) -> Void

    // Pour l'interface, on utilise des String pour éviter l'affichage de "0" par défaut au milieu du TextField
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    @State private var showingDelete = false

    var body: some View {
        HStack {
            Text("\(setNumber)")
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
                    handleWeightChange(newValue)
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
                    handleRepsChange(newValue)
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
                onDelete(setID)
            }
        } message: {
            Text("Cette action est irréversible.")
        }
        .onAppear {
            weightString = weight > 0 ? String(format: "%g", weight) : ""
            repsString = reps > 0 ? String(reps) : ""
        }
    }

    private func handleWeightChange(_ newValue: String) {
        let filtered = newValue.replacingOccurrences(of: ",", with: ".")
        if let weight = Double(filtered) {
            onWeightChange(setID, weight)
        }
    }

    private func handleRepsChange(_ newValue: String) {
        if let reps = Int(newValue) {
            onRepsChange(setID, reps)
        }
    }
}
