import Foundation
import Observation

/// The single source of truth for user bookmarks.
///
/// Owned by `AppEnvironment` and injected app-wide via SwiftUI's environment.
/// Because both `AppEnvironment` and this model are `@Observable`, any view that
/// reads `env.bookmarks.all` (or a derived property) re-renders on every
/// mutation — eliminating the stale one-shot `.task` snapshots the previous
/// architecture relied on.
///
/// **Mutation strategy — reload-after-mutate.** Every mutation performs its
/// store op(s) and then re-syncs `all = (try? store.all()) ?? all` rather than
/// editing the array in place. The store guarantees `createdAt`-descending
/// order, so ordering is correct for free, and a partial/mid-loop failure in a
/// batch (e.g. `deleteAll`) can never leave `all` diverged from the store.
/// Mutations swallow throws to match the existing `try?` call sites.
@MainActor
@Observable
public final class BookmarksModel {

    /// All bookmarks, newest first (the store guarantees `createdAt`-desc order).
    public private(set) var all: [Bookmark] = []

    private let store: any BookmarkStore

    public init(store: any BookmarkStore) {
        self.store = store
        reload()
    }

    /// Re-sync `all` from the backing store. Keeps the previous value on failure.
    public func reload() {
        all = (try? store.all()) ?? all
    }

    // MARK: - Mutations

    public func add(_ bookmark: Bookmark) {
        try? store.add(bookmark)
        reload()
    }

    public func delete(id: UUID) {
        try? store.delete(id: id)
        reload()
    }

    public func delete(ids: Set<UUID>) {
        for id in ids { try? store.delete(id: id) }
        reload()
    }

    public func deleteAll() {
        for bookmark in all { try? store.delete(id: bookmark.id) }
        reload()
    }

    public func rename(id: UUID, to name: String) {
        try? store.rename(id: id, to: name)
        reload()
    }

    public func setColor(id: UUID, _ colorTag: String?) {
        guard var bookmark = all.first(where: { $0.id == id }) else { return }
        bookmark.colorTag = colorTag
        try? store.update(bookmark)
        reload()
    }

    public func setEmoji(id: UUID, _ emojiTag: String?) {
        guard var bookmark = all.first(where: { $0.id == id }) else { return }
        bookmark.emojiTag = emojiTag
        try? store.update(bookmark)
        reload()
    }

    // MARK: - Derived read helpers (pure, computed over `all`)

    /// Total number of bookmarks.
    public var count: Int { all.count }

    /// Bookmarks anchored to a given book, newest first.
    public func bookmarks(bookId: String) -> [Bookmark] {
        all.filter { $0.anchor.bookId == bookId }
    }

    /// Highlight-kind bookmarks anchored to a given book, newest first.
    public func highlights(bookId: String) -> [Bookmark] {
        all.filter { $0.kind == .highlight && $0.anchor.bookId == bookId }
    }

    /// The highlight (if any) covering `sentenceId` within `bookId`.
    public func highlight(coveringSentence sentenceId: String, in bookId: String) -> Bookmark? {
        highlights(bookId: bookId).first { $0.anchor.sentenceIds.contains(sentenceId) }
    }
}
