import SwiftUI

// MARK: - Navigation destination helpers

/// Carries a resolved Book + optional initial sentence ID for reader navigation.
struct BookDestination: Hashable {
    let book: Book
    let sentenceId: String?
}

// MARK: - BookmarkManagementView

/// Full bookmark list grouped by kind with:
/// - Swipe-to-delete / rename (non-edit mode)
/// - Edit mode: multi-select 삭제(n) + 전체 삭제 (B2)
/// - Context menu: 색상 submenu for highlight rows (C2), 이모지 submenu for all rows (C3)
public struct BookmarkManagementView: View {
    @Environment(AppEnvironment.self) private var env

    /// Live bookmark list from the single source of truth. Reading this in
    /// `body`-derived views keeps the list in sync with every mutation.
    private var bookmarks: [Bookmark] { env.bookmarks.all }

    @State private var resolvedBooks: [String: Book] = [:]
    @State private var resolvedCollections: [String: BookCollection] = [:]
    @State private var isLoading = true

    // Swipe-delete flow (single item, non-edit mode)
    @State private var bookmarkToDelete: Bookmark?
    @State private var showDeleteConfirm = false

    // Rename flow
    @State private var bookmarkToRename: Bookmark?
    @State private var showRenameAlert = false
    @State private var renameText = ""

    // B2 — Edit mode
    @State private var editMode: EditMode = .inactive
    @State private var selectedIDs: Set<Bookmark.ID> = []
    @State private var showDeleteSelectedConfirm = false
    @State private var showDeleteAllConfirm = false

    /// Bookmarks grouped by kind, skipping empty kinds.
    private var grouped: [(BookmarkKind, [Bookmark])] {
        BookmarkKind.allCases.compactMap { kind in
            let items = bookmarks.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    public init() {}

    public var body: some View {
        ZStack {
            QuotesColor.surfacePrimary.ignoresSafeArea()
            contentBody
        }
        .navigationTitle("북마크")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !bookmarks.isEmpty || editMode.isEditing {
                    Button(editMode.isEditing ? "완료" : "편집") {
                        withAnimation {
                            if editMode.isEditing {
                                editMode = .inactive
                                selectedIDs.removeAll()
                            } else {
                                editMode = .active
                            }
                        }
                    }
                }
            }
        }
        // Auto-exit edit mode when list empties (e.g. after deleteAll)
        .onChange(of: bookmarks.count) { _, count in
            if count == 0 && editMode.isEditing {
                editMode = .inactive
                selectedIDs.removeAll()
            }
        }
        .task { await loadData() }
        // Swipe single-item delete confirmation
        .confirmationDialog(
            "북마크를 삭제할까요?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                guard let bm = bookmarkToDelete else { return }
                env.bookmarks.delete(id: bm.id)
            }
            Button("취소", role: .cancel) {}
        }
        // B2 — Multi-select delete confirmation
        .confirmationDialog(
            "선택한 \(selectedIDs.count)개의 북마크를 삭제할까요?",
            isPresented: $showDeleteSelectedConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제 (\(selectedIDs.count)개)", role: .destructive) {
                env.bookmarks.delete(ids: selectedIDs)
                selectedIDs.removeAll()
                withAnimation { editMode = .inactive }
            }
            Button("취소", role: .cancel) {}
        }
        // B2 — Delete all confirmation
        .confirmationDialog(
            "모든 북마크를 삭제할까요?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("전체 삭제", role: .destructive) {
                env.bookmarks.deleteAll()
                selectedIDs.removeAll()
                withAnimation { editMode = .inactive }
            }
            Button("취소", role: .cancel) {}
        }
        // Rename alert
        .alert("이름 변경", isPresented: $showRenameAlert) {
            TextField("새 이름", text: $renameText)
                .autocorrectionDisabled()
            Button("확인") {
                guard let bm = bookmarkToRename, !renameText.isEmpty else { return }
                env.bookmarks.rename(id: bm.id, to: renameText)
            }
            Button("취소", role: .cancel) {}
        }
        // Navigation destinations for Bookmark / BookDestination / BookCollection
        // are registered at the stack root in MyTabView — NOT here. Registering
        // them on this pushed view breaks the push transition on re-render
        // (previous screen overlaps the new one).
        // B2 — Bottom edit action bar (pushes list content up via safe-area inset)
        .safeAreaInset(edge: .bottom) {
            if editMode.isEditing && !bookmarks.isEmpty {
                editActionBar
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var contentBody: some View {
        if isLoading {
            VStack(spacing: QuotesSpacing.md) {
                ProgressView()
                    .tint(QuotesColor.accent)
                Text("불러오는 중…")
                    .font(.subheadline)
                    .foregroundStyle(QuotesColor.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if bookmarks.isEmpty {
            BrandedEmptyState(
                headline: "북마크가 없어요",
                subtext: "책을 읽으며 북마크를 추가해 보세요.",
                systemImage: "bookmark"
            )
        } else {
            bookmarkList
        }
    }

    // MARK: List

    private var bookmarkList: some View {
        // Attach the selection binding ONLY in edit mode. With it always
        // attached, a plain tap in browse mode also marks the row Selected,
        // which interferes with the row's NavigationLink activation.
        Group {
            if editMode.isEditing {
                List(selection: $selectedIDs) { listSections }
            } else {
                List { listSections }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(QuotesColor.surfacePrimary)
        .environment(\.editMode, $editMode)
    }

    @ViewBuilder
    private var listSections: some View {
        ForEach(grouped, id: \.0) { kind, items in
            Section {
                ForEach(items) { bookmark in
                    bookmarkRow(bookmark)
                }
            } header: {
                BookmarkSectionHeader(kind: kind, count: items.count)
            }
        }
    }

    // MARK: B2 — Edit action bar

    private var editActionBar: some View {
        HStack(spacing: QuotesSpacing.md) {
            // 삭제(n) — disabled when nothing is selected
            Button {
                showDeleteSelectedConfirm = true
            } label: {
                Text("삭제(\(selectedIDs.count))")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .disabled(selectedIDs.isEmpty)
            .buttonStyle(.borderedProminent)
            .tint(.red)

            // 전체 삭제
            Button("전체 삭제") {
                showDeleteAllConfirm = true
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.horizontal, QuotesSpacing.md)
        .padding(.top, QuotesSpacing.sm)
        .padding(.bottom, QuotesSpacing.md)
        .background(
            QuotesColor.surfacePrimary
                .overlay(alignment: .top) {
                    Divider()
                }
        )
    }

    // MARK: Row builder

    @ViewBuilder
    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        let ctx = contextTitle(for: bookmark)
        let row = BookmarkRowView(bookmark: bookmark, contextTitle: ctx)

        Group {
            switch bookmark.kind {
            case .capture:
                NavigationLink(value: bookmark) { row }

            case .highlight, .page:
                if let bookId = bookmark.anchor.bookId,
                   let book = resolvedBooks[bookId] {
                    NavigationLink(
                        value: BookDestination(
                            book: book,
                            sentenceId: bookmark.anchor.sentenceIds.first
                        )
                    ) { row }
                } else {
                    row
                }

            case .book:
                if let bookId = bookmark.anchor.bookId,
                   let book = resolvedBooks[bookId] {
                    NavigationLink(
                        value: BookDestination(book: book, sentenceId: nil)
                    ) { row }
                } else {
                    row
                }

            case .collection:
                if let collectionId = bookmark.anchor.collectionId,
                   let collection = resolvedCollections[collectionId] {
                    NavigationLink(value: collection) { row }
                } else {
                    row
                }
            }
        }
        .listRowBackground(QuotesColor.surfacePrimary)
        .listRowSeparatorTint(QuotesColor.cardStroke)
        // Swipe actions — only visible in non-edit mode (SwiftUI suppresses in edit mode)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                bookmarkToDelete = bookmark
                showDeleteConfirm = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                bookmarkToRename = bookmark
                renameText = bookmark.name
                showRenameAlert = true
            } label: {
                Label("이름 변경", systemImage: "pencil")
            }
            .tint(QuotesColor.accent)
        }
        // C2 (highlight color) + C3 (emoji) — context menu
        .contextMenu {
            // C3: Emoji submenu — all kinds
            Menu("이모지") {
                ForEach(["📌", "⭐️", "❤️", "🔥", "🌿", "📖", "💡", "✏️"], id: \.self) { emoji in
                    Button {
                        env.bookmarks.setEmoji(id: bookmark.id, emoji)
                    } label: {
                        Text(emoji)
                    }
                }
                Divider()
                Button("없음") {
                    env.bookmarks.setEmoji(id: bookmark.id, nil)
                }
            }

            // C2: Color submenu — highlight kind only
            if bookmark.kind == .highlight {
                Menu("색상") {
                    ForEach(HighlightPalette.Token.allCases) { token in
                        Button {
                            env.bookmarks.setColor(id: bookmark.id, token.rawValue)
                        } label: {
                            Label {
                                Text(token.koreanName)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(token.color)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Context title

    private func contextTitle(for bookmark: Bookmark) -> String? {
        switch bookmark.kind {
        case .collection:
            guard let id = bookmark.anchor.collectionId else { return nil }
            return resolvedCollections[id]?.title ?? id
        default:
            guard let id = bookmark.anchor.bookId else { return nil }
            return resolvedBooks[id]?.title ?? id
        }
    }

    // MARK: Data loading

    @MainActor
    private func loadData() async {
        isLoading = true
        let repo = env.contentRepository

        // Bookmarks come live from `env.bookmarks`; here we only resolve the
        // Book/Collection titles used for row context.
        let bookIds = Set(bookmarks.compactMap { $0.anchor.bookId })

        // Resolve books concurrently
        var resolved: [String: Book] = [:]
        await withTaskGroup(of: (String, Book)?.self) { group in
            for id in bookIds {
                group.addTask {
                    guard let book = try? await repo.book(id: id) else { return nil }
                    return (id, book)
                }
            }
            for await result in group {
                if let (id, book) = result {
                    resolved[id] = book
                }
            }
        }
        resolvedBooks = resolved

        // Resolve collections (batch call)
        if let cols = try? await repo.collections() {
            for col in cols {
                resolvedCollections[col.id] = col
            }
        }

        isLoading = false
    }
}

// MARK: - HighlightPalette.Token Korean display names

private extension HighlightPalette.Token {
    var koreanName: String {
        switch self {
        case .amber:    return "앰버"
        case .coral:    return "코랄"
        case .sage:     return "세이지"
        case .sky:      return "스카이"
        case .lavender: return "라벤더"
        }
    }
}

// MARK: - BookmarkSectionHeader

private struct BookmarkSectionHeader: View {
    let kind: BookmarkKind
    let count: Int

    var body: some View {
        HStack(spacing: QuotesSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(kind.kindColor.opacity(0.12))
                    .frame(width: 20, height: 20)
                Image(systemName: kind.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(kind.kindColor)
            }

            Text(kind.koreanName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuotesColor.inkSecondary)
                .textCase(nil)

            Spacer()

            Text("\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(kind.kindColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(kind.kindColor.opacity(0.1), in: Capsule())
        }
        .padding(.vertical, QuotesSpacing.xs)
    }
}

#Preview {
    NavigationStack {
        BookmarkManagementView()
            .environment(AppEnvironment.placeholder())
    }
}
