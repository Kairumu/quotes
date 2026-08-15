import SwiftUI
import SwiftData

/// App entry point.
///
/// Builds the SwiftData `ModelContainer` and an `AppEnvironment` with in-memory
/// placeholder services, then injects both into the view hierarchy. The
/// services worker later swaps the placeholder services for real
/// JSON/SwiftData-backed implementations.
@main
struct QuotesApp: App {
    private let modelContainer: ModelContainer
    @State private var environment: AppEnvironment

    init() {
        // Build the persistence container. Fall back to in-memory storage if the
        // on-disk store cannot be opened, so the app still launches.
        let container: ModelContainer
        do {
            container = try PersistenceSchema.container()
        } catch {
            // Best-effort fallback; an in-memory container should always succeed.
            container = try! PersistenceSchema.container(inMemory: true)
        }
        self.modelContainer = container
        _environment = State(initialValue: AppEnvironment.live(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment)
        }
        .modelContainer(modelContainer)
    }
}
