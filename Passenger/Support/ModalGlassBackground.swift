import SwiftUI

/// Shared Liquid Glass background for every modal-style surface in the app
/// (T-106/`PAS-106`, Aviran-direct, 2026-08-09 — "i want the modals will be
/// liquid glass"). One modifier so the six call sites
/// (`PassportSurface`, `PlacesListOverlay`, `SearchOverlay`,
/// `EventDetailModal`, `PlaceDetailModal`, `HoodSheet`) stay in lockstep —
/// tune the glass here, not per file.
///
/// **This reverses a previously deliberate, tested decision (`PAS-27`/
/// T-036), and that reversal is intentional, not a rediscovered
/// regression.** These same six surfaces used to render an *opaque*
/// `Color("Surface")` background specifically because translucent chrome
/// over the live, constantly-changing map made shipped text unreadable —
/// see `PassportSurface.swift`'s prior header comment (now superseded) and
/// `PAS-27`'s own fix, `.thickMaterial` → `Color("Surface")`. Since then,
/// `ContrastRatioTests`/`PlacesListContrastTests` (`Support/ContrastRatio.swift`,
/// WCAG AA 4.5:1) have guarded against that regression on every build. They
/// still run and still pass under this change, but they only ever measured
/// the *static* asset-catalog color pair (e.g. `MutedOnSurface` vs.
/// `Surface`) — never the *live composite* of glass-over-map, which is
/// exactly the case this modifier reintroduces and exactly what those tests
/// cannot see. Aviran was told this in those terms, with the readability
/// tradeoff spelled out, before deciding. His answer, verbatim: **"option
/// 2"** — full glass everywhere, matching his own reference screenshot,
/// contrast-verification gap knowingly accepted. Full record:
/// `passenger-brain/agent-os/PROGRESS.md`'s 2026-08-09 "Liquid glass
/// modals: founder-direct decision record" entry; Linear `PAS-106`.
///
/// **Consequence for future readers/reviewers:** on-map text legibility
/// under this background is a **human eyeball check**, not a
/// machine-verifiable one — re-check it live (light *and* dark mode, real
/// map content underneath) whenever the map's rendered color range changes
/// materially (a new heat palette, denser markers, a new time-of-day tint),
/// not only once at ship time. A future session finding real legibility
/// problems here is rediscovering a known, accepted tradeoff, not
/// uncovering a new bug — raise it as a design question (does the tint need
/// tuning?), not as a "someone forgot the opaque-background rule" finding.
struct ModalGlassBackground: ViewModifier {
    /// Top-two-corners-only, 20pt — unchanged from the shape this replaces
    /// (`design-principles.md` §8, T-079/`PAS-73`). This modifier is a
    /// material swap only; it does not touch width, anchoring, or corners.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 20,
            style: .continuous
        )
    }

    func body(content: Content) -> some View {
        // `.regular`, never `.clear` — `.clear` is only appropriate over
        // media-rich content with an acceptable dimming layer and bold
        // content on top (Liquid Glass rules, HIG); these cards carry body
        // text and controls at every content length, including the
        // sparsest real data (an empty Hood, a place with no route yet), so
        // `.regular`'s adaptive-legibility behavior is the only variant
        // that's even attempting to protect text contrast here. Don't mix
        // `.clear` into a subset of these six — one variant, app-wide.
        content.glassEffect(.regular, in: shape)
    }
}

extension View {
    /// Applies the app-wide modal Liquid Glass treatment (T-106/`PAS-106`).
    /// See `ModalGlassBackground`'s doc comment for the full rationale,
    /// the tested decision this reverses, and the readability tradeoff
    /// Aviran accepted to get it.
    func modalGlassBackground() -> some View {
        modifier(ModalGlassBackground())
    }
}
