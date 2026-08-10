import SwiftUI

/// The nav row (T-032 D1/D6, TRD §2.3 z7): "separate side-by-side buttons,
/// no shared container chrome" — so the search button (search-quick-filters
/// TRD §11 C6) and the profile/Passport button (passport TRD §11 C7) sit
/// here with no re-layout and no shared background, border, or grouping
/// added.
///
/// **T-099/`PAS-99` (2026-08-09): no longer always visible — this is a
/// deliberate reversal of the rule below, not an oversight.** T-032 D1/D6
/// and T-078/`PAS-60` reopened (`nav-row-v2-redesign.md`) both established
/// and then twice reaffirmed "always visible, always hit-testable, never
/// covered" as this row's standing rule. Per Aviran's own direct
/// instruction ("when opening any modal (from nav bar) remove the nav bar
/// buttons"), that rule no longer holds while a surface this row itself
/// opened is presented: `MapScreen` wraps this view's call site in
/// `if !chrome.isPresenting`, so all 3 buttons are removed from the
/// hierarchy entirely (not faded, not disabled — gone, along with this
/// row's own `mapNavRow` accessibility container) for as long as
/// `chrome.presented` is non-nil (`.search`, `.places`, or `.profile`), and
/// restored the instant it clears (`chrome.dismiss()`/`chrome.toggle()`
/// back to `nil`). Each of the 3 presented surfaces
/// (`SearchOverlay`/`PlacesListOverlay`/`PassportSurface`) owns its own
/// independent dismiss affordances (a "Close" button, a scrim tap, a
/// downward drag) that don't depend on this row, so hiding it doesn't strand
/// anyone inside a surface — see each surface's own file. **Not affected:**
/// the depth-1 marker-tap destinations (Hood/Place/Event detail, via
/// `MapScreen.depth1SheetContent()`) aren't opened from this row and don't
/// touch `chrome.presented`, so this change doesn't apply to them.
/// `architect` owes a follow-up doc-only note on `time-slider/TRD.md` §2.3
/// z7 reflecting this (not a build blocker — flagged, not yet written as of
/// this commit).
///
/// **Assistive technology (`PAS-97`, merged into this ticket after the
/// initial dispatch): hiding this row must not strand a VoiceOver or Switch
/// Control user inside a surface.** It doesn't, and the reason is
/// structural, not something bolted on for this ticket: each surface's
/// "Close" button (`closeButton` in `SearchOverlay`/`PlacesListOverlay`/
/// `PassportSurface`) is a plain SwiftUI `Button` with an explicit
/// `.accessibilityLabel("Close")`, never `.accessibilityHidden`, and lives
/// entirely inside the presented surface's own view tree — none of that
/// depends on this row or its 3 buttons being present. VoiceOver reaches it
/// by the standard swipe-navigation order same as any other on-screen
/// control, and Switch Control reaches it the same way it reaches any
/// accessible `Button` — by scanning the same accessibility tree, not by a
/// row-specific affordance. `SearchAccessibilityTests
/// .testTappingCloseButtonDismissesTheOverlay`,
/// `PlacesListInteractionTests.testDismissViaCloseButtonReturnsToListlessMap`,
/// and `ProfileButtonInteractionTests
/// .testTappingCloseButtonDismissesPassportAndRestoresNavRow` all drive this
/// exact button through `XCUIElement`, which resolves through the same
/// `UIAccessibility` tree VoiceOver and Switch Control read — that is live
/// proof the element is reachable and correctly labeled, not just present
/// in source. **Disclosed limitation:** this toolchain has no automated way
/// to drive a live Switch Control scan or a live VoiceOver announcement
/// inside a UI test (no simulator API for either, unlike the documented
/// Dynamic Type route in `passenger-code/CLAUDE.md`'s Simulator facts) — the
/// claim above is structural (a standard, labeled, unhidden `Button`, proven
/// reachable via the same tree both technologies read), not a literal
/// on-device AT recording. `MapNavRow`'s own 3 buttons already carried
/// `.accessibilityLabel`s of their own (`SearchButton`/`ProfileButton`/
/// `PlacesButton`) — hiding the row while a surface is open removes them
/// from that tree entirely along with the row's `mapNavRow` container, so
/// an AT user navigating the screen no longer lands on a button that reads
/// as present but (per this same ticket) does nothing useful in that state.
///
/// **PAS-42 (2026-08-04, founder-direct): 5 icon buttons lived here.**
/// `NearMeButton` and `PlacesButton` moved in from a second, lower
/// "bucket-2 chrome" row so all 5 buttons shared one show/hide rule (D1's
/// "always visible, always hit-testable, never covered," not D7's fade).
///
/// **T-078/`PAS-60` reopened (`nav-row-v2-redesign.md`): back down to 3.**
/// `HeatButton` is deleted — its function folded into `SearchButton`'s own
/// surface as an in-overlay "Hour" segment (`SearchOverlay.swift` §1), so
/// there is no longer a 4th button for it. `NearMeButton` relocated again,
/// this time out of this row entirely into `MapScreen`'s top-trailing
/// overlay (Apple/Google-Maps-style placement, §2) — it keeps the same
/// always-visible behavior it had here, just at a new home. `PlacesButton`
/// stays, with its PAS-42 no-fade/no-`isFaded`-parameter behavior and its
/// `MapScreen.openPlacesList` re-tap guard both unchanged by this pass.
struct MapNavRow: View {
    let isSearchPresented: Bool
    let onSearchTap: () -> Void
    let isPassportPresented: Bool
    let onProfileTap: () -> Void
    let onPlacesTap: () -> Void

    var body: some View {
        // `GlassEffectContainer` (T-107/`PAS-107`, HIG "grouping Liquid Glass
        // elements"): these 3 circles sit side by side, close enough that
        // their independent glass samples would otherwise clash rather than
        // read as one row — a container is a correctness requirement here
        // (glass can't sample other glass; nearby glass shapes need to share
        // one container so they blend/light consistently), not a
        // performance nicety. `spacing: 16` matches the `HStack`'s own
        // layout spacing rather than an arbitrary default, so the container's
        // proximity threshold agrees with what's actually on screen. This
        // does not change the row's own long-standing rule (T-032 D1/D6,
        // above) — "separate side-by-side buttons, no shared container
        // chrome" was about not adding a *visible* background/border behind
        // all 3; `GlassEffectContainer` renders nothing of its own, it only
        // coordinates how the 3 already-independent `.glassEffect()` circles
        // sample and blend.
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                SearchButton(isPresented: isSearchPresented, action: onSearchTap)
                ProfileButton(isPresented: isPassportPresented, action: onProfileTap)
                PlacesButton(action: onPlacesTap)
            }
        }
        // TRD §9 row 5b's own build note: this row's frame, as a whole,
        // needs to be queryable from a UI test. The individual buttons
        // already carry their own labels ("Search"/"Profile"/"Places") for
        // regression tests; this is the container's own identity, not a
        // replacement for those. **Order matters here** (found live at
        // C16, T-077/`PAS-51`): `.accessibilityElement(children: .contain)`
        // must come *before* `.accessibilityIdentifier(...)` — the other
        // way around, the identifier cascades onto each child button
        // individually instead of binding to the row's own container
        // element, and `app.otherElements["mapNavRow"]` never matches
        // anything. `SearchOverlay`'s `hourSegmentCard` identifier (C16)
        // uses this same order and was verified working first.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mapNavRow")
    }
}
