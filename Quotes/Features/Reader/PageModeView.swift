import SwiftUI

/// Paginated reading: sentences are packed into fixed pages and navigated
/// horizontally (swipe or edge tap). Each page renders the SAME sentence-based
/// components as sentence mode, so tap-select, highlight tint, translations and
/// drag-select behave identically. Page numbers are derived from sentence
/// anchors and cached per layout — never stored.
struct PageModeView: View {
    let model: ReaderModel
    let selection: ReaderSelectionModel
    @Binding var chromeHidden: Bool
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var paginated: PaginatedBook?
    @State private var currentPage = 0
    @State private var availableSize: CGSize = .zero

    private let pageTopPadding: CGFloat = 8
    private let indicatorReserve: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if let paginated, !paginated.pages.isEmpty {
                    pagedContent(paginated)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                availableSize = size
                repaginate()
            }
            .onChange(of: size) { _, newValue in
                availableSize = newValue
                repaginate()
            }
        }
        .onChange(of: dynamicTypeSize) { repaginate() }
        .onChange(of: env.showTranslation) { repaginate() }
        .onChange(of: env.translationLanguage) { repaginate() }
        .onChange(of: currentPage) { updatePagePosition() }
        .onChange(of: model.pendingScrollTarget) { _, target in
            jumpToPendingTarget(target)
        }
    }

    // MARK: Paged content

    @ViewBuilder
    private func pagedContent(_ book: PaginatedBook) -> some View {
        TabView(selection: $currentPage) {
            ForEach(Array(book.pages.enumerated()), id: \.offset) { index, page in
                pageView(page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .leading) { edgeTapZone { goToPage(currentPage - 1) } }
        .overlay(alignment: .trailing) { edgeTapZone { goToPage(currentPage + 1) } }
        .overlay(alignment: .bottom) { pageIndicator(count: book.pages.count) }
    }

    @ViewBuilder
    private func pageView(_ blocks: [PageBlock]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ReaderStyle.rowSpacing) {
                ForEach(blocks) { block in
                    switch block {
                    case .title(_, let text):
                        Text(text)
                            .font(.title3.bold())
                            .padding(.top, ReaderStyle.titleTopPadding)
                            .padding(.bottom, ReaderStyle.titleBottomPadding)
                            .padding(.horizontal, ReaderStyle.rowHorizontalPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .sentence(let sentence, let chunkId):
                        SentenceRowView(
                            sentence: sentence,
                            chunkId: chunkId,
                            model: model,
                            selection: selection
                        )
                    }
                }
            }
            .padding(.top, pageTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .contentShape(Rectangle())
        .dragToSelect(model: model, selection: selection)
        .onTapGesture { toggleChrome() }
    }

    // MARK: Overlays

    private func edgeTapZone(_ action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    @ViewBuilder
    private func pageIndicator(count: Int) -> some View {
        if count > 0 {
            Text("\(min(currentPage + 1, count)) / \(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 10)
                .opacity(chromeHidden ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: chromeHidden)
                .allowsHitTesting(false)
        }
    }

    // MARK: Navigation

    private func goToPage(_ target: Int) {
        guard let paginated else { return }
        let clamped = max(0, min(target, paginated.pages.count - 1))
        guard clamped != currentPage else { return }
        withAnimation(.easeInOut(duration: 0.2)) { currentPage = clamped }
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.2)) { chromeHidden.toggle() }
    }

    // MARK: Pagination

    private func repaginate() {
        let contentSize = CGSize(
            width: availableSize.width,
            height: max(1, availableSize.height - pageTopPadding - indicatorReserve)
        )
        guard contentSize.width > 1, contentSize.height > 1 else { return }

        let firstTime = (paginated == nil)
        let anchorSentence = targetSentenceId(firstTime: firstTime)

        let key = LayoutKey(
            bookVersion: model.book.version,
            size: contentSize,
            dynamicTypeSize: dynamicTypeSize,
            showTranslation: env.showTranslation,
            translationLanguage: env.translationLanguage
        )
        let result = model.paginated(for: key)
        paginated = result

        if let anchorSentence, let page = result.pageIndexBySentence[anchorSentence] {
            currentPage = page
        } else {
            currentPage = min(currentPage, max(0, result.pages.count - 1))
        }

        if firstTime, model.pendingScrollTarget != nil {
            model.pendingScrollTarget = nil
        }
        updatePagePosition()
    }

    /// The sentence the new layout should stay anchored to. On the first layout
    /// this honours an initial/bookmark target or the restored position; on
    /// rotation/resize it keeps the previously-visible page's first sentence.
    private func targetSentenceId(firstTime: Bool) -> String? {
        if !firstTime, let existing = paginated {
            return existing.firstSentenceId(onPage: currentPage) ?? model.currentPositionSentenceId
        }
        return model.pendingScrollTarget ?? model.currentPositionSentenceId
    }

    private func jumpToPendingTarget(_ target: String?) {
        guard let target,
              let paginated,
              let page = paginated.pageIndexBySentence[target] else { return }
        currentPage = page
        model.pendingScrollTarget = nil
        updatePagePosition()
    }

    private func updatePagePosition() {
        model.notePagePosition(firstSentenceId: paginated?.firstSentenceId(onPage: currentPage))
    }
}
