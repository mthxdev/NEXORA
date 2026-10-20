import SwiftUI
import SwiftData
import UserNotifications

@main
struct NexoraApp: App {
    @AppStorage("appearance") private var appearance: AppAppearance = .system

    init() {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [
            Program.self,
            WorkoutTemplate.self,
            ExerciseTemplate.self,
            CompletedWorkout.self,
            CompletedExercise.self,
            CompletedSet.self,
            MovieEntry.self,
            SeriesEntry.self,
            AnimeEntry.self,
            GameEntry.self,
            ProjectEntry.self,
            LearningEntry.self,
            FavoriteRecipe.self
         ]) { result in
            switch result {
            case .success(let container):
                Task { @MainActor in
                    InitialDataLoader.loadIfEmpty(context: container.mainContext)
                    BackupManager.shared.recoverFromFallback(context: container.mainContext)
                    BackupManager.shared.autoBackup(context: container.mainContext)
                    MealService.shared.setModelContext(container.mainContext)
                }
            case .failure(let error):
                print("NexoraApp: ModelContainer creation failed: \(error)")
            }
        }
    }
}
