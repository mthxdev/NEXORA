import Foundation
import SwiftData

@Model
final class ExerciseTemplate {
    var id: UUID
    var name: String
    var targetSets: Int
    var targetReps: String
    var displayOrder: Int
    var workout: WorkoutTemplate?

    init(name: String, targetSets: Int = 3, targetReps: String = "8-10", displayOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.displayOrder = displayOrder
    }
}
