import SwiftUI
import UIKit

/// Which logical unit maps to one carousel screen.
enum ReaderUnitGranularity {
    /// One sentence per screen (문장).
    case sentence
    /// One paragraph per screen (문단).
    case paragraph
}

/// One logical unit rendered on a single carousel screen. A sentence unit holds
/// exactly one sentence; a paragraph unit holds the paragraph's sentences. The
/// owning chunk `title` is carried only on that chunk's first unit.
struct ReaderUnit: Identifiable, Hashable {
    let id: String
    let chunkId: String
    let title: String?
    let sentences: [Sentence]
}

/// Horizontal, one-unit-per-screen carousel shared by 문장 and 문단 modes.
///
/// Clones the `PageModeView` pattern — `TabView(.page)` for free horizontal
/// swipe, edge-tap paging, tap-to-toggle chrome — but performs **no text
/// measurement**: each unit is one logical page. An oversized unit (병기 at
/// large Dynamic Type) scrolls vertically inside its own screen instead of
/// clipping. Positions feed ONLY the `notePagePosition` pipeline; deep links and
/// mode switches land via `pendingScrollTarget` + `unitIndex(of:granularity:)`.
struct UnitCarouselView: View {
    let granularity: ReaderUnitGranularity
    let model: ReaderModel
    let selection: ReaderSelectionModel
    @Binding var chromeHidden: Bool
    @Environment(AppEnvironment.self) private var env

    @State private var currentIndex = 0

    private let pageTopPadding: CGFloat = 8

    private var units: [ReaderUnit] { model.units(for: granularity) }

    var body: some View {
        ZStack {
            if !units.isEmpty {
                carousel
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { landInitial() }
        .onChange(of: currentIndex) {
            // Unit-scoped selection: a selection never spans off-screen units.
            selection.clear()
            updatePosition()
        }
        .onChange(of: model.pendingScrollTarget) { _, target in
            jumpToPending(target)
        }
    }

    // MARK: Carousel

    @ViewBuilder
    private var carousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(units.enumerated()), id: \.offset) { index, unit in
                unitPage(unit).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .leading) { edgeTapZone { goToUnit(currentIndex - 1) } }
        .overlay(alignment: .trailing) { edgeTapZone { goToUnit(currentIndex + 1) } }
        .overlay(alignment: .bottom) { progressCapsule }
    }

    @ViewBuilder
    private func unitPage(_ unit: ReaderUnit) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ReaderStyle.rowSpacing) {
                if let title = unit.title {
                    Text(title)
                        .font(.title3.bold())
                        .padding(.top, ReaderStyle.titleTopPadding)
                        .padding(.bottom, ReaderStyle.titleBottomPadding)
                        .padding(.horizontal, ReaderStyle.rowHorizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                unitBody(unit)
            }
            .padding(.top, pageTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .contentShape(Rectangle())
        // NO dragToSelect here: the long-press-then-drag gesture delays touch
        // delivery to TabView's paging recognizer and swallows horizontal
        // swipes — pages stop flipping. In carousels, selection is tap-based
        // (tap-select / tap-to-extend on rows and chips), which already covers
        // the on-screen-unit selection scope; full drag-select lives in
        // 이어보기 (ContinuousModeView) only.
        .onTapGesture { toggleChrome() }
    }

    @ViewBuilder
    private func unitBody(_ unit: ReaderUnit) -> some View {
        switch granularity {
        case .sentence:
            if let sentence = unit.sentences.first {
                SentenceRowView(
                    sentence: sentence,
                    chunkId: unit.chunkId,
                    model: model,
                    selection: selection
                )
            }
        case .paragraph:
            ParagraphFlowBlock(
                sentences: unit.sentences,
                chunkId: unit.chunkId,
                model: model,
                selection: selection
            )
            .padding(.horizontal, ReaderStyle.rowHorizontalPadding)
            .padding(.vertical, ReaderStyle.rowVerticalPadding)
        }
    }

    // MARK: Overlays

    private func edgeTapZone(_ action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    /// Combined "n / N · %" progress capsule rendered BY the paged view (the
    /// ReaderScreen-level `%` capsule is 이어보기-only, avoiding a double capsule).
    @ViewBuilder
    private var progressCapsule: some View {
        if !units.isEmpty {
            let n = min(currentIndex + 1, units.count)
            let pct = Int((model.progressFraction * 100).rounded())
            Text("\(n) / \(units.count) · \(pct)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 10)
                .opacity(chromeHidden ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: chromeHidden)
                .allowsHitTesting(false)
                .accessibilityIdentifier("reader.progress")
        }
    }

    // MARK: Navigation

    private func goToUnit(_ target: Int) {
        let clamped = max(0, min(target, units.count - 1))
        guard clamped != currentIndex else { return }
        setIndex(clamped, animated: true)
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.2)) { chromeHidden.toggle() }
    }

    /// Sets the current unit, honouring Reduce Motion (no page animation when set).
    private func setIndex(_ index: Int, animated: Bool) {
        if animated && !UIAccessibility.isReduceMotionEnabled {
            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = index }
        } else {
            currentIndex = index
        }
    }

    // MARK: Position + deep-link landing

    /// On first appearance, land on the pending target (deep link / mode switch)
    /// or the restored reading position; otherwise clamp the current index.
    private func landInitial() {
        let target = model.pendingScrollTarget ?? model.currentPositionSentenceId
        if let target, let index = model.unitIndex(of: target, granularity: granularity) {
            currentIndex = index
        } else {
            currentIndex = min(currentIndex, max(0, units.count - 1))
        }
        if model.pendingScrollTarget != nil {
            model.pendingScrollTarget = nil
        }
        updatePosition()
    }

    /// Honour a deep-link / mode-switch target arriving after appearance.
    private func jumpToPending(_ target: String?) {
        guard let target,
              let index = model.unitIndex(of: target, granularity: granularity) else { return }
        setIndex(index, animated: true)
        model.pendingScrollTarget = nil
        updatePosition()
    }

    private func updatePosition() {
        guard units.indices.contains(currentIndex) else { return }
        model.notePagePosition(firstSentenceId: units[currentIndex].sentences.first?.id)
    }
}
