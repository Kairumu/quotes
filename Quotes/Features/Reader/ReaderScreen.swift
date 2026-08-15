import SwiftUI
import UIKit

/// The reading surface for a single book.
///
/// Public entry point used by other features: push it inside a
/// `NavigationStack` and optionally pass `initialSentenceId` to open at a
/// specific sentence (e.g. from a bookmark). When omitted, the saved reading
/// position is restored; otherwise it opens at the top.
public struct ReaderScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.displayScale) private var displayScale

    @State private var model: ReaderModel
    @State private var selection = ReaderSelectionModel()

    @State private var renameBookmark: Bookmark?
    @State private var renameText = ""
    @State private var shareItem: ShareableImage?

    /// Pending highlight color for the next 하이라이트 creation (C2). Applied at
    /// creation time; the swatch row shows a ring on the active token.
    @State private var selectedColorTag: String = HighlightPalette.defaultToken.rawValue
    /// Pending emoji tag for the next 하이라이트 creation (C3). `nil` = no emoji.
    @State private var selectedEmojiTag: String?

    /// Fixed emoji set offered on create (C3, LOCKED). `nil` (없음) is a
    /// separate leading chip in the picker.
    private let emojiChoices = ["📌", "⭐️", "❤️", "🔥", "🌿", "📖", "💡", "✏️"]

    /// Immersive reading: hides the mode bar and navigation chrome in page mode.
    @State private var chromeHidden = false

    public init(book: Book, initialSentenceId: String? = nil) {
        _model = State(initialValue: ReaderModel(book: book, initialSentenceId: initialSentenceId))
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) { progressIndicator }
            .background(alignment: .top) { readerTopTint }
            .background(ReaderStyle.readingBackground.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) { modeBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { selectionBar }
            .navigationTitle(model.book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .toolbar(chromeHidden ? .hidden : .visible, for: .navigationBar)
            .statusBarHidden(chromeHidden)
            .animation(.easeInOut(duration: 0.2), value: selection.isActive)
            .animation(.easeInOut(duration: 0.2), value: chromeHidden)
            .task { await model.load(env: env) }
            .onDisappear { model.persistPosition() }
            .alert("북마크 이름", isPresented: renameAlertPresented) {
                TextField("이름", text: $renameText)
                Button("저장") { commitRename() }
                Button("취소", role: .cancel) { renameBookmark = nil }
            } message: {
                Text("이 북마크의 이름을 정하세요.")
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.image])
            }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .loading:
            ProgressView("불러오는 중…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("불러오지 못했어요", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("재시도") { Task { await model.load(env: env) } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded:
            switch env.viewMode {
            case .paragraph:
                ParagraphModeView(model: model, selection: selection, chromeHidden: $chromeHidden)
            case .sentence:
                SentenceModeView(model: model, selection: selection, chromeHidden: $chromeHidden)
            case .page:
                PageModeView(model: model, selection: selection, chromeHidden: $chromeHidden)
            }
        }
    }

    // MARK: Progress + palette tint

    /// Unobtrusive percent-progress capsule for the scrolling modes (page mode
    /// keeps its own `n / N` indicator). Hides with chrome and while a selection
    /// bar is showing to avoid overlap.
    @ViewBuilder
    private var progressIndicator: some View {
        if model.loadState == .loaded,
           env.viewMode != .page,
           !chromeHidden,
           !selection.isActive {
            Text("\(Int((model.progressFraction * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 10)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: chromeHidden)
        }
    }

    /// Faint top tint derived from the book's `BookPalette`, fading into the
    /// reading background. Background only — body text/contrast is unaffected.
    private var readerTopTint: some View {
        BookPalette.token(for: model.book).backgroundGradient
            .frame(height: 240)
            .frame(maxWidth: .infinity, alignment: .top)
            .mask(
                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(0.45)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }

    // MARK: Top mode bar

    @ViewBuilder
    private var modeBar: some View {
        if model.loadState == .loaded && !chromeHidden {
            VStack(spacing: 0) {
                Picker("보기 모드", selection: viewModeBinding) {
                    Text("문장").tag(ReaderViewMode.sentence)
                    Text("문단").tag(ReaderViewMode.paragraph)
                    Text("페이지").tag(ReaderViewMode.page)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                Divider()
            }
            .background(.bar)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var viewModeBinding: Binding<ReaderViewMode> {
        Binding(
            get: { env.viewMode },
            set: { newValue in
                guard newValue.isAvailable, newValue != env.viewMode else { return }
                // Preserve reading position: land the new mode on the same sentence.
                model.pendingScrollTarget = model.currentPositionSentenceId
                if newValue != .page { chromeHidden = false }
                env.viewMode = newValue
            }
        )
    }

    // MARK: Selection action bar

    @ViewBuilder
    private var selectionBar: some View {
        if selection.isActive {
            Group {
                // When the selection touches an existing highlight, the bar
                // offers removal instead of creation (B1). A non-highlighted
                // selection shows the normal create bar with color/emoji pickers.
                if model.highlightsIntersecting(selection).isEmpty {
                    creationBar
                } else {
                    removalBar
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Create bar: pending color swatches + emoji picker (row 1) above the
    /// 하이라이트 / 캡처 / 취소 actions (row 2).
    private var creationBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                swatchRow
                Divider().frame(height: 22)
                emojiRow
            }
            HStack(spacing: 20) {
                Button { highlightSelection() } label: {
                    Label("하이라이트", systemImage: "highlighter")
                }
                .tint(.primary)
                Divider().frame(height: 22)
                Button { captureSelection() } label: {
                    Label("캡처", systemImage: "camera.viewfinder")
                }
                .tint(.primary)
                Divider().frame(height: 22)
                Button { selection.clear() } label: {
                    Label("취소", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .tint(.secondary)
            }
        }
    }

    /// Removal bar shown when the selection intersects a highlight (B1).
    private var removalBar: some View {
        HStack(spacing: 20) {
            Button(role: .destructive) { removeHighlightSelection() } label: {
                Label("하이라이트 제거", systemImage: "trash")
            }
            .tint(.red)
            Divider().frame(height: 22)
            Button { selection.clear() } label: {
                Label("취소", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .tint(.secondary)
        }
    }

    /// Five palette color dots; the active one carries a ring (C2).
    private var swatchRow: some View {
        HStack(spacing: 8) {
            ForEach(HighlightPalette.Token.allCases) { token in
                Button {
                    selectedColorTag = token.rawValue
                } label: {
                    Circle()
                        .fill(token.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().strokeBorder(
                                .primary,
                                lineWidth: selectedColorTag == token.rawValue ? 2 : 0
                            )
                        )
                        .padding(1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(token.rawValue)
            }
        }
    }

    /// Horizontally scrollable emoji picker: a leading 없음 chip then the fixed
    /// emoji set; the active choice carries a ring (C3).
    private var emojiRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                emojiChip(nil)
                ForEach(emojiChoices, id: \.self) { emoji in
                    emojiChip(emoji)
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(maxWidth: 168)
    }

    @ViewBuilder
    private func emojiChip(_ emoji: String?) -> some View {
        let isSelected = selectedEmojiTag == emoji
        Button {
            selectedEmojiTag = emoji
        } label: {
            Group {
                if let emoji {
                    Text(emoji)
                } else {
                    Image(systemName: "slash.circle").foregroundStyle(.secondary)
                }
            }
            .font(.body)
            .frame(width: 26, height: 26)
            .background(Circle().fill(isSelected ? Color.accentColor.opacity(0.22) : .clear))
            .overlay(Circle().strokeBorder(.primary, lineWidth: isSelected ? 1.5 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emoji ?? "없음")
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                env.showTranslation.toggle()
            } label: {
                Image(systemName: env.showTranslation ? "character.bubble.fill" : "character.bubble")
            }
            .accessibilityLabel("번역 표시")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    offerRename(model.createPageBookmark())
                } label: {
                    Label("현재 위치 북마크", systemImage: "bookmark")
                }
                Button {
                    offerRename(model.createBookBookmark())
                } label: {
                    Label("책 북마크", systemImage: "book")
                }
                let saved = env.bookmarks.bookmarks(bookId: model.book.id)
                    .filter { $0.kind == .page || $0.kind == .book }
                if !saved.isEmpty {
                    Section("이 책의 북마크") {
                        ForEach(saved) { bookmark in
                            Button(role: .destructive) {
                                env.bookmarks.delete(id: bookmark.id)
                            } label: {
                                Label(bookmark.name, systemImage: "trash")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "bookmark")
            }
            .disabled(model.loadState != .loaded)
        }
    }

    // MARK: Actions

    private func highlightSelection() {
        // Color/emoji are applied at creation; the existing rename alert follows
        // unchanged (C2/C3).
        let bookmark = model.createHighlight(
            from: selection,
            colorTag: selectedColorTag,
            emojiTag: selectedEmojiTag
        )
        selection.clear()
        offerRename(bookmark)
    }

    private func removeHighlightSelection() {
        model.removeHighlights(intersecting: selection)
        selection.clear()
    }

    private func captureSelection() {
        guard let result = model.createCapture(from: selection) else { return }
        selection.clear()
        if let image = renderCaptureImage(sentences: result.sentences) {
            shareItem = ShareableImage(image: image)
        }
    }

    private func renderCaptureImage(sentences: [Sentence]) -> UIImage? {
        let card = CaptureCardView(
            sentences: sentences,
            book: model.book,
            showTranslation: env.showTranslation,
            translationLanguage: env.translationLanguage
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = displayScale
        return renderer.uiImage
    }

    // MARK: Rename

    private var renameAlertPresented: Binding<Bool> {
        Binding(
            get: { renameBookmark != nil },
            set: { if !$0 { renameBookmark = nil } }
        )
    }

    private func offerRename(_ bookmark: Bookmark?) {
        guard let bookmark else { return }
        renameText = bookmark.name
        renameBookmark = bookmark
    }

    private func commitRename() {
        if let bookmark = renameBookmark {
            model.applyRename(id: bookmark.id, to: renameText)
        }
        renameBookmark = nil
    }
}
