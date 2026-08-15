import SwiftUI

/// Continuous scroll-offset telemetry + hysteresis chrome-hide for the scrolling
/// reader modes (sentence / paragraph).
///
/// iOS 17 has **no** `onScrollGeometryChange`, and `.scrollPosition(id:)` yields
/// a row *id* — not a continuous offset — so it cannot express scroll direction.
/// We track a real offset with the same primitive already used for drag-select
/// (`SentenceSelection.swift`): a `GeometryReader` in the scroll content's
/// background, a **named coordinate space** on the `ScrollView`, and a
/// `PreferenceKey` publishing the content's `minY` (and height, for bottom-edge
/// detection). Frame-to-frame delta of that offset gives direction.
///
/// The tracker is **read-only telemetry**: it never touches
/// `noteVisibility(_:visible:)`, `visibleSentenceIds`, scroll anchoring, or the
/// position-save pipeline. It only flips the shared `chromeHidden` flag.

/// A single scroll-offset sample: the content top's `minY` in the reader scroll
/// coordinate space plus the content height (used to detect the bottom edge).
struct ReaderScrollSample: Equatable {
    var minY: CGFloat
    var contentHeight: CGFloat
}

/// Publishes the latest `ReaderScrollSample` from the scroll content.
struct ReaderScrollOffsetKey: PreferenceKey {
    static var defaultValue = ReaderScrollSample(minY: 0, contentHeight: 0)
    static func reduce(value: inout ReaderScrollSample, nextValue: () -> ReaderScrollSample) {
        value = nextValue()
    }
}

/// Named coordinate space the reader scroll offset is measured in (distinct from
/// the drag-select space so the two never interfere).
enum ReaderScroll {
    static let space = "reader.scroll.offset.space"
}

/// Hysteresis state machine that decides when to hide/show chrome from a stream
/// of offset samples. Held as `@State` (a stable reference) inside the modifier;
/// its mutations intentionally do **not** trigger re-render.
@MainActor
final class ReaderChromeTracker {
    private var lastOffset: CGFloat?
    /// Accumulated same-direction travel since the last flip / direction change.
    private var accumulated: CGFloat = 0
    private var lastFlip = Date.distantPast
    /// Detection is muted until this instant to swallow the one offset jump the
    /// top `safeAreaInset` resize produces when `chromeHidden` toggles.
    private var suppressUntil = Date.distantPast

    /// Accumulated travel (pt) required before a hide/show flip (dead-band).
    private let deadband: CGFloat = 24
    /// Minimum interval between flips (anti-oscillation).
    private let minFlipInterval: TimeInterval = 0.25
    /// How long to mute detection after a `chromeHidden` change.
    private let suppressWindow: TimeInterval = 0.3
    /// Ignore sub-pixel jitter.
    private let noiseFloor: CGFloat = 0.5

    /// Call whenever `chromeHidden` changes (from any source) to suppress the
    /// inset-resize offset jump that would otherwise re-trigger the detector.
    func noteChromeChange() {
        suppressUntil = Date().addingTimeInterval(suppressWindow)
        lastOffset = nil
        accumulated = 0
    }

    /// Feed one offset sample. `setHidden` is invoked only when a flip is due.
    func handle(
        sample: ReaderScrollSample,
        viewportHeight: CGFloat,
        chromeHidden: Bool,
        setHidden: (Bool) -> Void
    ) {
        let offset = sample.minY

        // Boundary return (Naver-derived): always show chrome at top/bottom.
        let atTop = offset >= -2
        let atBottom = viewportHeight > 0 && sample.contentHeight > 0
            && (offset + sample.contentHeight) <= viewportHeight + 2
        if atTop || atBottom {
            if chromeHidden { setHidden(false) }
            lastOffset = offset
            accumulated = 0
            return
        }

        let now = Date()
        // Swallow the inset-resize jump for one window after a chrome change.
        if now < suppressUntil {
            lastOffset = offset
            return
        }

        guard let last = lastOffset else {
            lastOffset = offset
            return
        }
        let delta = offset - last          // <0 scrolling down, >0 scrolling up
        lastOffset = offset
        if abs(delta) < noiseFloor { return }

        // Reset accumulation when direction reverses.
        if (delta < 0) != (accumulated < 0) { accumulated = 0 }
        accumulated += delta

        guard now.timeIntervalSince(lastFlip) >= minFlipInterval else { return }

        if accumulated <= -deadband && !chromeHidden {
            setHidden(true)
            lastFlip = now
            accumulated = 0
        } else if accumulated >= deadband && chromeHidden {
            setHidden(false)
            lastFlip = now
            accumulated = 0
        }
    }
}

extension View {
    /// Publishes this scroll content's offset for chrome-hide tracking. Apply to
    /// the scroll content (e.g. the `LazyVStack`), inside the `ScrollView` the
    /// `readerChromeHide` modifier wraps.
    func trackReaderScrollOffset() -> some View {
        background(
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(ReaderScroll.space))
                Color.clear.preference(
                    key: ReaderScrollOffsetKey.self,
                    value: ReaderScrollSample(minY: frame.minY, contentHeight: frame.height)
                )
            }
        )
    }

    /// Drives hysteresis chrome-hide from scroll offset. Apply to the
    /// `ScrollView`; the content must carry `trackReaderScrollOffset()`.
    func readerChromeHide(chromeHidden: Binding<Bool>) -> some View {
        modifier(ReaderChromeHideModifier(chromeHidden: chromeHidden))
    }
}

/// Wires the named coordinate space, viewport measurement, and preference→tracker
/// plumbing for scroll-driven chrome hide.
private struct ReaderChromeHideModifier: ViewModifier {
    @Binding var chromeHidden: Bool
    @State private var tracker = ReaderChromeTracker()
    @State private var viewportHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: ReaderScroll.space)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { viewportHeight = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, height in
                            viewportHeight = height
                        }
                }
            )
            .onPreferenceChange(ReaderScrollOffsetKey.self) { sample in
                tracker.handle(
                    sample: sample,
                    viewportHeight: viewportHeight,
                    chromeHidden: chromeHidden
                ) { newHidden in
                    guard newHidden != chromeHidden else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { chromeHidden = newHidden }
                    tracker.noteChromeChange()
                }
            }
            .onChange(of: chromeHidden) { _, _ in
                // External flips (mode switch, page-mode tap) also resize the
                // inset — suppress the resulting offset jump.
                tracker.noteChromeChange()
            }
    }
}
