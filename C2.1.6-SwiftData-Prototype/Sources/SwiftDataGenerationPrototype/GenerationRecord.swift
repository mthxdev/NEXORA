import Foundation
import SwiftData

@Model
public final class GenerationRecord {
    public var id: UUID
    public var generation: String
    public var label: String
    public var value: Int

    public init(id: UUID = UUID(), generation: String, label: String, value: Int) {
        self.id = id
        self.generation = generation
        self.label = label
        self.value = value
    }
}

@Model
public final class GenerationStoreMarker {
    public var id: UUID
    public var generationID: String

    public init(id: UUID = UUID(), generationID: String) {
        self.id = id
        self.generationID = generationID
    }
}

public enum GenerationStoreFactory {
    public static func makeContainer(at url: URL, name: String) throws -> ModelContainer {
        let schema = Schema([GenerationRecord.self, GenerationStoreMarker.self])
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: nil,
            configurations: [configuration]
        )
    }

    public static func records(in context: ModelContext) throws -> [GenerationRecord] {
        try context.fetch(FetchDescriptor<GenerationRecord>())
    }

    public static func markers(in context: ModelContext) throws -> [GenerationStoreMarker] {
        try context.fetch(FetchDescriptor<GenerationStoreMarker>())
    }
}
