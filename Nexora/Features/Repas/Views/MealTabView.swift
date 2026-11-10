import SwiftUI

struct MealTabView: View {
    var body: some View {
        NavigationStack {
            MealHomeView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NexoraSettingsToolbarButton()
                    }
                }
        }
    }
}
