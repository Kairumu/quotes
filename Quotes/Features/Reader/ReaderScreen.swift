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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    /// One-shot auto-hide state machine (T3). `autoHideTask` non-nil ⇔ armed;
    /// `autoHideConsumed` true ⇔ fired or cancelled (terminal, never re-arms).
    @State private var autoHideTask: Task<Void, Never>?
    @State private var autoHideConsumed = false

    /// Kill switch honoured by UI tests that assert reader chrome past the 3s mark.
    private var autoHideDisabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-disableChromeAutoHide")
    }

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
            .toolbar(chromeHidden ? .hidden : .visible, for: .tabBar)
            .statusBarHidden(chromeHidden)
            .animation(.easeInOut(duration: 0.2), value: selection.isActive)
            // Single value-animation source for chrome; ~0.3s lands the auto-fade
            // in the 0.3–0.5s spec window and doubles as the manual-toggle timing.
            // Reduce Motion → no animation (instant), matching UnitCarouselView.
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: chromeHidden)
            .task {
                await model.load(env: env)
                // Arm right after load resolves, covering the case where the
                // state change lands before .onChange observes it.
                armAutoHide()
            }
            .onChange(of: model.loadState) { armAutoHide() }
            .onChange(of: chromeHidden) { cancelAutoHide() }
            .onChange(of: model.currentPositionSentenceId) { old, _ in
                // Genuine navigation (swipe to next unit, sub-hysteresis scroll)
                // moves between two real sentences → cancel. The initial landing
                // establishes position as nil → sentence; that is NOT a user
                // interaction, so it must not consume the one-shot timer.
                if old != nil { cancelAutoHide() }
            }
            // N1: a mode switch within the armed window sets chromeHidden = false
            // when it is ALREADY false, so onChange(chromeHidden) alone misses it.
            .onChange(of: env.viewMode) { cancelAutoHide() }
            .onDisappear {
                model.persistPosition()
                autoHideTask?.cancel()
            }
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
            case .sentence:
                UnitCarouselView(granularity: .sentence, model: model, selection: selection, chromeHidden: $chromeHidden)
            case .paragraph:
                UnitCarouselView(granularity: .paragraph, model: model, selection: selection, chromeHidden: $chromeHidden)
            case .page:
                PageModeView(model: model, selection: selection, chromeHidden: $chromeHidden)
            case .continuous:
                ContinuousModeView(model: model, selection: selection, chromeHidden: $chromeHidden)
            }
        }
    }

    // MARK: Progress + palette tint

    /// Unobtrusive percent-progress capsule for 이어보기 only. The paged modes
    /// (문장/문단/페이지) render their own combined "n / N · %" capsule, so this
    /// is gated to `.continuous` to avoid a double capsule. Hides with chrome and
    /// while a selection bar is showing to avoid overlap.
    @ViewBuilder
    private var progressIndicator: some View {
        if model.loadState == .loaded,
           env.viewMode == .continuous,
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
                // 4-segment mode control (문장/문단/페이지/이어보기). Labels come
                // from `ReaderViewMode.displayName` so the picker and UI tests
                // share one source. If this truncates at large Dynamic Type /
                // SE width, swap to a scrollable chip row keeping the identifier.
                Picker("보기 모드", selection: viewModeBinding) {
                    Text(ReaderViewMode.sentence.displayName).tag(ReaderViewMode.sentence)
                    Text(ReaderViewMode.paragraph.displayName).tag(ReaderViewMode.paragraph)
                    Text(ReaderViewMode.page.displayName).tag(ReaderViewMode.page)
                    Text(ReaderViewMode.continuous.displayName).tag(ReaderViewMode.continuous)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("reader.mode.picker")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                Divider()
            }
            .background(.bar)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var displayModeBinding: Binding<TranslationDisplayMode> {
        Binding(
            get: { env.translationDisplay },
            set: { env.translationDisplay = $0 }
        )
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { env.translationLanguage },
            set: { env.translationLanguage = $0 }
        )
    }

    private var viewModeBinding: Binding<ReaderViewMode> {
        Binding(
            get: { env.viewMode },
            set: { newValue in
                guard newValue.isAvailable, newValue != env.viewMode else { return }
                // Preserve reading position: land the new mode on the same
                // sentence (works across all 4 modes via pendingScrollTarget).
                model.pendingScrollTarget = model.currentPositionSentenceId
                // A mode switch is a user interaction: cancel any pending
                // auto-hide. Required here because the setter writes
                // chromeHidden = false, which does NOT fire onChange when chrome
                // was already visible.
                cancelAutoHide()
                // Reset chrome on any switch: paged modes use tap-to-toggle;
                // 이어보기 re-derives visibility from scroll.
                chromeHidden = false
                env.viewMode = newValue
            }
        )
    }

    // MARK: Auto-hide state machine (T3)

    /// idle → armed. One-shot: guarded so it never re-arms after firing or
    /// cancellation, and stays disabled under the `-disableChromeAutoHide` flag.
    private func armAutoHide() {
        guard !autoHideConsumed, autoHideTask == nil, !autoHideDisabled else { return }
        guard model.loadState == .loaded else { return }
        autoHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            fireAutoHide()
        }
    }

    /// armed → fired. Mark terminal BEFORE flipping chrome so the
    /// `onChange(chromeHidden)` observer treats this as a no-op cancel.
    @MainActor
    private func fireAutoHide() {
        guard !autoHideConsumed else { return }
        autoHideConsumed = true
        autoHideTask = nil
        if reduceMotion {
            chromeHidden = true
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { chromeHidden = true }
        }
    }

    /// armed → cancelled. Terminal; any user-driven chrome interaction lands here.
    private func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
        autoHideConsumed = true
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
            Menu {
                Picker("번역 표시", selection: displayModeBinding) {
                    ForEach(TranslationDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Picker("번역 언어", selection: languageBinding) {
                    ForEach(AppEnvironment.languageOptions(for: model.book), id: \.self) { code in
                        Text(AppEnvironment.languageDisplayName(code)).tag(code)
                    }
                }
            } label: {
                Image(systemName: env.translationDisplay == .originalOnly ? "character.bubble" : "character.bubble.fill")
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
            displayMode: env.translationDisplay,
            translationLanguage: env.effectiveLanguage(for: model.book)
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
