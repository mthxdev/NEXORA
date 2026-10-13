import Foundation
import SwiftData

@Model
final class Program {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.program)
    var workouts: [WorkoutTemplate]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.workouts = []
    }
}
