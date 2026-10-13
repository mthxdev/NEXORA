import Foundation
import SwiftData

@Model
final class CompletedWorkout {
    var id: UUID
    var date: Date
    var startedAt: Date
    var finishedAt: Date?
    var programName: String
    var workoutName: String
    @Relationship(deleteRule: .cascade, inverse: \CompletedExercise.workout)
    var exercises: [CompletedExercise]

    init(programName: String, workoutName: String) {
        self.id = UUID()
        self.date = Date()
        self.startedAt = Date()
        self.programName = programName
        self.workoutName = workoutName
        self.exercises = []
    }
}
