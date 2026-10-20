import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject private var service = NotificationService.shared
    @State private var selectedTime: Date = Date()
    @State private var isEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle("Rappel d'entraînement", isOn: $isEnabled)
                    .onChange(of: isEnabled) { newValue in
                        Task {
                            await handleToggle(newValue)
                        }
                    }
            } footer: {
                Text("Recevez une notification quotidienne à l'heure choisie pour vous rappeler de faire votre entraînement.")
            }

            if isEnabled {
                Section {
                    DatePicker(
                        "Heure du rappel",
                        selection: $selectedTime,
                        displayedComponents: [.hourAndMinute]
                    )
                }

                Section {
                    Button("Enregistrer l'heure") {
                        Task {
                            await saveReminderTime()
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("Statut")
                    Spacer()
                    Text(authorizationStatusText)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }

            if service.authorizationStatus == .denied {
                Section {
                    Button("Ouvrir les réglages") {
                        openAppSettings()
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isEnabled = service.isReminderEnabled
            selectedTime = service.reminderTime
        }
    }

    private var authorizationStatusText: String {
        switch service.authorizationStatus {
        case .authorized:
            return "Autorisé"
        case .denied:
            return "Non autorisé"
        case .notDetermined:
            return "Non demandé"
        default:
            return "Inconnu"
        }
    }

    private func handleToggle(_ enabled: Bool) async {
        if enabled {
            let granted = await service.requestAuthorization()
            if granted {
                let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                let hour = components.hour ?? 8
                let minute = components.minute ?? 0
                await service.enableReminders(hour: hour, minute: minute)
            } else {
                isEnabled = false
            }
        } else {
            await service.disableReminders()
        }
    }

    private func saveReminderTime() async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0
        await service.enableReminders(hour: hour, minute: minute)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
