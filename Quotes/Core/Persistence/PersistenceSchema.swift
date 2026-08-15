import Foundation
import SwiftData

/// Central SwiftData schema definition and container factory.
public enum PersistenceSchema {
    /// All persisted model types.
    public static let models: [any PersistentModel.Type] = [
        BookmarkRecord.self,
        ReadingPositionRecord.self
    ]

    /// The versioned schema.
    public static var schema: Schema {
        Schema(models)
    }

    /// Build a configured `ModelContainer`.
    /// - Parameter inMemory: when true, data lives only for the process lifetime
    ///   (previews/tests). Defaults to on-disk persistence.
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
