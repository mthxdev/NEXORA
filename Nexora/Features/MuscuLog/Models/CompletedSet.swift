import Foundation
import SwiftData

@Model
final class CompletedSet {
    var id: UUID
    var weight: Double
    var reps: Int
    var setNumber: Int
    var exercise: CompletedExercise?

    init(weight: Double, reps: Int, setNumber: Int) {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.setNumber = setNumber
    }
}
