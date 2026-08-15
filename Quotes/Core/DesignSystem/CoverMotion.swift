import SwiftUI

// MARK: - CoverBreathingModifier
//
// Procedural "breathing" oscillation for book cover surfaces — Kakao-quality
// restraint: alive but not a carnival. Applied only to grid-size covers; compact
// (carousel) covers stay static for scroll performance.
//
// Design parameters
// ─────────────────
//   Period      8 s — slow, serene. One full inhale-exhale every 8 seconds.
//   Scale amp   ±1.2 % of the view's natural size. Sub-perceptual but present.
//   Brightness  ±3 % brightness nudge in sync with scale. Adds warmth to the pulse.
//   Phase       Derived from `seed` (caller passes `BookPalette.fnv1a(book.id)`).
//               Phase offset = (seed % 1000) / 1000 × 2π — distributes adjacent
//               covers across the full oscillation cycle so they never pulse in lock-step.
//
// Reduce Motion
// ─────────────
//   When `@Environment(\.accessibilityReduceMotion)` is true, the modifier returns
//   content UNMODIFIED — no TimelineView is instantiated at all, so there is zero
//   tick overhead and the layout is pixel-identical to the static cover.
//
// Offscreen cost
// ──────────────
//   `TimelineView(.animation)` is driven by SwiftUI's rendering pipeline. When a
//   cover scrolls outside the visible clip region the pipeline stops issuing frames
//   to it, so the TimelineView effectively pauses. No explicit visibility gating is
//   needed.

private let kBreathPeriod: Double = 8.0      // full cycle in seconds
private let kScaleAmplitude: Double = 0.012  // ± fraction of 1.0  (1.2 %)
private let kBrightnessAmp: Double = 0.03    // ± brightness units  (3 %)

struct CoverBreathingModifier: ViewModifier {
    /// Stable UInt32 seed derived from the book id (e.g. `BookPalette.fnv1a(book.id)`).
    /// Used to compute a unique phase offset so adjacent covers desync their pulses.
    let seed: UInt32

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // Completely static — no TimelineView, no animation overhead.
            content
        } else {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                // Unique phase offset in [0, 2π) per book → desync across the grid.
                let phaseOffset = Double(seed % 1000) / 1_000.0 * 2.0 * .pi
                let angle = (t / kBreathPeriod) * 2.0 * .pi + phaseOffset
                let sinV = sin(angle)   // in [-1, 1]

                content
                    .scaleEffect(1.0 + sinV * kScaleAmplitude)
                    .brightness(sinV * kBrightnessAmp)
            }
        }
    }
}

extension View {
    /// Apply a procedural "breathing" oscillation to a cover surface.
    ///
    /// - Parameter seed: A stable `UInt32` from `BookPalette.fnv1a(book.id)`.
    ///   Adjacent covers receive different phase offsets so they never pulse in sync.
    ///
    /// Only call this on grid-size covers. Compact / carousel covers should remain
    /// static — the canonical gating is in `BookCoverView.body` (`size == .grid`).
    func coverBreathing(seed: UInt32) -> some View {
        modifier(CoverBreathingModifier(seed: seed))
    }
}
