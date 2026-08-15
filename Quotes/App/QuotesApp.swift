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

        #if DEBUG
        // UI-test hook: seed a deterministic highlight bookmark before the
        // environment (and its BookmarksModel) loads from the store.
        if ProcessInfo.processInfo.arguments.contains("-seedTestBookmark") {
            MainActor.assumeIsolated {
                let store = SwiftDataBookmarkStore(modelContainer: container)
                let existing = (try? store.all()) ?? []
                if !existing.contains(where: { $0.name == "UITEST-HL" }) {
                    try? store.add(Bookmark(
                        kind: .highlight,
                        name: "UITEST-HL",
                        anchor: BookmarkAnchor(
                            bookId: "b001",
                            chunkId: "b001-c002",
                            sentenceIds: ["b001-c002-p002-s002"]
                        ),
                        colorTag: "sage"
                    ))
                }
            }
        }
        #endif

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
