import SwiftUI

/// Value-based routes pushed from the 서재 (Books) tab root.
///
/// The Books `NavigationStack` registers **only** this single enum at its root
/// (see `BooksTabView`). Every push in the Books stack is value-based
/// (`NavigationLink(value: BooksRoute…)`) — there are no label-based
/// `NavigationLink { Destination() }` closures and no bare
/// `BookDestination`/`Book`/`BookCollection` destinations registered alongside
/// it. This mirrors the `MyRoute` pattern and avoids the double-push / overlap
/// bug class caused by (a) mixing label- and value-based links in one stack and
/// (b) double-registering a target under two value types.
enum BooksRoute: Hashable {
    case collection(BookCollection)
    case bookDetail(Book)
    /// Reuses the existing `BookDestination { book, sentenceId }`.
    case reader(BookDestination)
}
