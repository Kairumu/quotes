import Foundation

/// CRUD access to user bookmarks. Implementations may be backed by SwiftData
/// or an in-memory array (placeholder/tests).
public protocol BookmarkStore: Sendable {
    /// All bookmarks, newest first is recommended but not required.
    func all() throws -> [Bookmark]
    /// Bookmarks of a given kind.
    func bookmarks(kind: BookmarkKind) throws -> [Bookmark]
    /// Bookmarks anchored to a given book.
    func bookmarks(bookId: String) throws -> [Bookmark]
    /// Insert a new bookmark.
    func add(_ bookmark: Bookmark) throws
    /// Rename an existing bookmark.
    func rename(id: UUID, to name: String) throws
    /// Overwrite an existing bookmark's mutable fields (`name`, `colorTag`,
    /// `emojiTag`) from the given domain value, matched by `id`. Throws
    /// `BookmarkStoreError.notFound` if no record matches.
    func update(_ bookmark: Bookmark) throws
    /// Delete a bookmark by ID.
    func delete(id: UUID) throws
}
