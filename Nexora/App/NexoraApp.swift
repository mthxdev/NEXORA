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
            LearningEntry.self
        ]) { result in
            if case .success(let container) = result {
                InitialDataLoader.loadIfEmpty(context: container.mainContext)
            }
        }
    }
}