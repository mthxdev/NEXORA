import Foundation
import SwiftData

@Model
final class CompletedExercise {
    var id: UUID
    var exerciseName: String
    var displayOrder: Int
    var workout: CompletedWorkout?
    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.exercise)
    var sets: [CompletedSet]

    init(exerciseName: String, displayOrder: Int = 0) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.displayOrder = displayOrder
        self.sets = []
    }
}
