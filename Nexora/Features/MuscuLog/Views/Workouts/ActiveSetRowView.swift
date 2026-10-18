import SwiftUI
import SwiftData

struct ActiveSetRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var set: CompletedSet

    // Pour l'interface, on utilise des String pour éviter l'affichage de "0" par défaut au milieu du TextField
    @State private var weightString: String = ""
    @State private var repsString: String = ""

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
                    set.weight = Double(filtered) ?? 0
                    saveContext()
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
                    set.reps = Int(newValue) ?? 0
                    saveContext()
                }

            Text("reps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.vertical, 2)
        .onAppear {
            if set.weight > 0 {
                weightString = String(format: "%g", set.weight)
            }
            if set.reps > 0 {
                repsString = String(set.reps)
            }
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Impossible de sauvegarder la série : \(error.localizedDescription)")
        }
    }
}
