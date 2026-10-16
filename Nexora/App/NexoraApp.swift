import SwiftUI
import SwiftData

@main
struct NexoraApp: App {
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
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
                InitialDataLoader.loadIfEmpty(context: container.mainContext)
                BackupManager.shared.autoBackup(context: container.mainContext)
                MealService.shared.setModelContext(container.mainContext)
            case .failure(let error):
                print("NexoraApp: ModelContainer creation failed: \(error)")
            }
        }
    }
}
