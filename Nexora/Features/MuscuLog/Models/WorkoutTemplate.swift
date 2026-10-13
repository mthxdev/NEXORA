import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var displayOrder: Int
    var program: Program?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.workout)
    var exercises: [ExerciseTemplate]

    init(name: String, displayOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.displayOrder = displayOrder
        self.exercises = []
    }
}
