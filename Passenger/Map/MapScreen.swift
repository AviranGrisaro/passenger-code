import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// The app's single screen (TRD §2.1). Owns the camera and composes
/// `Hoods/` geometry with `Density/` bands — the only layer that knows both
/// (TRD §2.2). Nothing on the cold-open path `await`s before the first frame:
/// the map is pannable, zoomable, and tappable from frame one, before
/// geometry, density, or permission resolve (PRD req 1, TRD §5.1).
struct MapScreen: View {
    private static let telAvivCityWide = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 32.0853, longitude: 34.7818),
        span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
    )

    /// UI-test-only override (T-033/PAS-13 acceptance fix pass). Launched
    /// with `-uiTestZoomedIn`, the app starts already zoomed in past
    /// `MapZoomTier.closeSpanThreshold` (renamed in place from
    /// `nameLabelSpanThreshold`, tourist-trap-flag TRD §2.3 — same value, no
    /// behaviour change), centered on a known bundled place, so
    /// `DetailSheetInteractionTests` can exercise the pin-tap path — now
    /// gated on `showsNames` — deterministically. A synthesized pinch and
    /// `doubleTap()` were both tried first to move the camera mid-test and
    /// neither reliably worked (see that test file's header); setting the
    /// *initial* camera sidesteps the gesture problem entirely. A real
    /// launch never carries this argument, so it always sees
    /// `telAvivCityWide`.
    private static var initialCameraRegion: MKCoordinateRegion {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestZoomedIn") else {
            return telAvivCityWide
        }
        // kerem-suzana-yemenite-kitchen (kerem-hateimanim) — the same
        // fixture coordinate `DetailSheetInteractionTests` taps.
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 32.068407, longitude: 34.76525),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }

    /// UI-test-only camera exposure (TRD §9 row 7e / C13 — the check the
    /// TRD requires before that step can be called done: `MKCoordinateRegion`
    /// byte-identical across an in-band vertical edge drag, "the same
    /// comparison method §9 row 2c already uses"). Neither `camera` nor
    /// `MKCoordinateRegion` is otherwise observable from an XCUITest
    /// process — this is the same class of test-only seam as
    /// `-uiTestZoomedIn` above, gated behind its own launch argument so it
    /// carries zero cost/behaviour in a real launch. **[ASSUMPTION]**: the
    /// TRD specifies the comparison, not the exposure mechanism — this is
    /// this task's own construction for it, flagged for `ios-code-reviewer`
    /// to confirm rather than assumed correct by construction alone.
    private static let isExposingCameraRegionForTests = ProcessInfo.processInfo.arguments.contains("-uiTestExposeCameraRegion")

    private static func regionDump(_ region: MKCoordinateRegion) -> String {
        String(
            format: "%.8f,%.8f,%.8f,%.8f",
            region.center.latitude, region.center.longitude,
            region.span.latitudeDelta, region.span.longitudeDelta
        )
    }

    @State private var camera: MapCameraPosition = .region(initialCameraRegion)
    @State private var cameraRegionDump: String = ""
    @State private var hoods: [Hood] = []
    @State private var hitTester = HoodHitTester(hoods: [])
    /// Design fix (2026-08-04): the Hood under the pointer, so `HoodLayer`
    /// can glow its border. Pointer-only — `onContinuousHover` only ever
    /// fires from a trackpad/Pointer device (iPad/Mac idiom), so this stays
    /// `nil` for the lifetime of a touch-only session and every Hood renders
    /// exactly as it did before this property existed.
    @State private var hoveredHoodID: Hood.ID?
    /// The single derivation of zoom from span (tourist-trap-flag TRD §2.2,
    /// §2.3) — the map never asks "close enough to show names/pins?" and
    /// "close enough to show the flag label?" as two independently-computed
    /// booleans that could silently disagree.
    @State private var zoomTier: MapZoomTier = .cityWide
    /// Visible at `.close` and closer only (design spec §2 — "Hood zoom and
    /// closer only") — unchanged threshold and unchanged behaviour from
    /// before the flag existed; only the derivation moved to `MapZoomTier`.
    private var showsNames: Bool { zoomTier == .close }
    /// The map's own centre, kept in sync from `onMapCameraChange` — the
    /// point `HoodButton` resolves its "nearest Hood" against (TRD §4.7), no
    /// new geometry needed beyond the existing `HoodHitTester`.
    @State private var cameraCenterPoint = MKMapPoint(x: 0, y: 0)

    @State private var settingsHintVisible = false
    @State private var settingsHintDismissTask: Task<Void, Never>?

    // C15 (TRD §11, `PAS-51` finding 4): `UITestOverrides.now` defaults to
    // live `Date()` exactly like the `Date.init` default this replaced —
    // pinned only under `-uiTestNow`, so a real launch is unaffected.
    @State private var densityStore = DensityStore(now: UITestOverrides.now)
    @State private var locationStore = LocationStore()
    @State private var permissionPrompt: PermissionPrompt?

    /// The live in-progress edge drag, or `nil` between drags (TRD §4.8).
    /// Drives `EdgeHourTrack`'s presence and position — mutually exclusive
    /// with any presented `NavSurface`/sheet by construction, since
    /// `EdgeHourZone` (the only writer) isn't in the hierarchy in either
    /// state (§2.3, §4.10).
    @State private var edgeDrag: EdgeDragState?

    // T-033: place/Hood detail (TRD §2.1). One session-scoped catalog, one
    // router, read by both sheets and the pin layer — no per-sheet fetch.
    @State private var placeCatalog = PlaceCatalog()
    @State private var savedPlacesStore = SavedPlacesStore()
    @State private var detailRouter = DetailRouter()

    // scenic-walk (T-057): the 5-minute session memo, one instance for the
    // app's lifetime (TRD §4.7, A2) — created here alongside the other
    // session-scoped stores. `routePreviewModel` is `Optional` and populated
    // in a `.task` below, the same lazy-construction pattern
    // `permissionPrompt` already uses (§11), because its `init` needs
    // `locationStore`/`routeMemoStore` and a `@State` property's default
    // value can't reference another stored property on `self`. Once
    // populated it is never replaced — "torn down on dismiss" (TRD §4.4) is
    // implemented as `reset()` clearing its state, not as re-instantiation,
    // matching how `detailRouter`/`savedPlacesStore` are already
    // long-lived, mutated-in-place session objects rather than recreated
    // per presentation.
    @State private var routeMemoStore = RouteMemoStore()
    @State private var routePreviewModel: RoutePreviewModel?

    // scenic-walk (T-057, TRD §4.9, amendment A3): the camera's bottom inset
    // is derived from these two measured heights, never a device constant.
    // Both start at 0 (unmeasured); `fittedRegion` reads that as "no sheet
    // height known yet" and fits with zero inset rather than guessing (A3's
    // stated edge case), and `hasFitWithMeasuredSheetHeight` gates the one
    // permitted re-fit once a real height arrives.
    @State private var mapViewportHeight: CGFloat = 0
    @State private var presentedSheetHeight: CGFloat = 0
    @State private var hasFitWithMeasuredSheetHeight = false

    // places-been-saved (T-036): the second provenance source (§3.1) and the
    // one-surface-at-a-time chrome state T-032 owns (§2.2) — created here
    // because no other build order landed it first in this working tree; if
    // T-032's own C1 lands later it finds `MapChromeState.swift` already
    // correct and adds nothing to it.
    @State private var visitedPlacesStore = VisitedPlacesStore()
    @State private var chrome = MapChromeState()

    // search-quick-filters (T-038): the session-scoped query/chip state
    // (TRD §4.6) and the derived index (§3.3, §4.2) — rebuilt off the
    // cold-open path once both catalogs resolve (`onChange` below), never
    // persisted.
    @State private var searchSession = SearchSession()
    @State private var searchIndex = SearchIndex.empty

    // T-034: the live-events overlay (TRD §2.1). One session-scoped store,
    // read by both the map layer and `handleTap` — no per-marker fetch.
    @State private var eventStore = EventStore()

    // tourist-trap-flag (T-035): the ask loop (TRD §2.1, §2.2). `MapScreen`
    // reaches `LocalQAAnswerStore` only transitively through the
    // coordinator, never directly — the same composition-root pattern as
    // `placeCatalog`/`hoods` above, and explicitly not a finding (TRD §2.2).
    @State private var localQACoordinator = LocalQACoordinator()
    @State private var localQAPresenter = LocalQAPresenter()

    /// The Hood whose polygon contains the camera's centre right now, or
    /// `nil` between Hoods — `HoodButton` hides itself in that gap rather
    /// than naming the nearest one by distance (TRD §4.7).
    private var nearestHood: Hood? {
        hitTester.hood(at: cameraCenterPoint, tolerance: 0)
    }

    /// A `Binding` into `densityStore.selectedHour` (TRD §4.3) — there is
    /// exactly one storage location for the hour in the entire app; this is
    /// how both `HourSlider` and `EdgeHourZone` write to it without either
    /// gaining a second, private copy.
    private var selectedHourBinding: Binding<Int> {
        Binding(get: { densityStore.selectedHour }, set: { densityStore.selectedHour = $0 })
    }

    /// The formatted readout for whichever hour is currently selected (TRD
    /// §3.2, §4.4) — read fresh on every render pass, `.current` calendar,
    /// real wall clock, never cached.
    private var currentReadout: HourFormat.Readout {
        HourFormat.readout(
            offset: densityStore.selectedHour, anchorHour: densityStore.anchorHour,
            // C15 (TRD §11, `PAS-51` finding 4): pinned under `-uiTestNow`,
            // live `Date()` otherwise — same seam as `densityStore` above,
            // so the readout's "next day" pill and `densityStore`'s own
            // anchor never disagree about what "now" is.
            now: UITestOverrides.now(), calendar: .current
        )
    }

    /// One resolution per render pass through `HeatComposition` (TRD §4.7),
    /// instead of calling `densityStore.band(...)` inline per Hood — this is
    /// the repaint's single nameable completion point, so
    /// `HeatRepaintSignpost.endIfPending()` has one place to be called from
    /// regardless of which writer (`HourSlider` or `EdgeHourZone`) started
    /// the interval.
    private var hoodFills: [HoodFill] {
        let fills = HeatComposition.fills(hoods: hoods, hour: densityStore.selectedHour) { hoodID, hour in
            densityStore.band(for: hoodID, hour: hour)
        }
        HeatRepaintSignpost.endIfPending()
        return fills
    }

    /// Pulled out of `body`'s `Map { }` builder closure (design fix,
    /// 2026-08-04): inlined there, adding `HoodLayer`'s new `isHovered`
    /// argument pushed that single `MapContentBuilder` expression — already
    /// large, with events/places/user-location siblings in the same closure
    /// — past the type checker's time limit ("unable to type-check this
    /// expression in reasonable time"). Factored into its own `some
    /// MapContent` property, the exact same content type-checks instantly;
    /// `Map`'s builder accepts a nested `MapContent` value exactly like a
    /// nested `ForEach`, so this changes nothing about what's drawn.
    @MapContentBuilder
    private var hoodLayers: some MapContent {
        ForEach(hoodFills, id: \.hood.id) { fill in
            HoodLayer(
                hood: fill.hood,
                band: fill.band,
                zoomTier: zoomTier,
                isDimmed: isHoodDimmed(fill.hood),
                isHovered: isHoodHovered(fill.hood)
            )
        }
    }

    /// scenic-walk TRD §1.2, §4.9, D9: drawn on the main map behind the
    /// sheet, not in a mini-map inside it — the PRD's own req 1 bullet asks
    /// that a route line be distinguishable from a Hood's outline at
    /// neighborhood zoom, and Hood outlines exist only here. `nil` whenever
    /// nothing has resolved yet, which renders nothing (TRD §9 row 1c).
    private var fastAndScenicPlans: (fast: RoutePlan, scenic: RoutePlan?)? {
        guard case .resolved(let fast, let scenicResult) = routePreviewModel?.preview else { return nil }
        return (fast, try? scenicResult.get())
    }

    /// The Places list's read-time precedence merge (places-been-saved TRD
    /// §4.3) — a dictionary read over already-loaded data, run once per
    /// render pass, never a per-sheet fetch.
    private var placesListEntries: [PlacesListEntry] {
        PlacesListComposition.entries(
            places: placeCatalog.allPlaces,
            saved: savedPlacesStore.savedPlaceIDs,
            visits: visitedPlacesStore.visits
        )
    }

    /// The event markers this render pass actually draws (T-034 TRD §4.4,
    /// §4.6). `handleTap`'s event branch hit-tests exactly this same set, so
    /// rendering and tap resolution can never disagree — the discipline
    /// T-033's acceptance REJECT established for the place-pin/zoom gate,
    /// applied here to the hour/cap gate instead.
    private var visibleEvents: [LiveEvent] {
        EventSelection.selected(
            from: eventStore.events,
            anchorHour: densityStore.anchorHour,
            offset: densityStore.selectedHour,
            now: Date()
        )
    }

    // T-037: Passport's read-time composition (TRD §4.1, §11 C11) — pure
    // functions over already-loaded data, run once per render pass, never a
    // per-open fetch. `registry: .shared` is the bundled, synchronous
    // `PlaceTypeRegistry` (TRD §3.4) — no `.task` loads it.
    private var passportStickers: [PassportSticker] {
        PassportComposition.stickers(
            places: placeCatalog.allPlaces, visits: visitedPlacesStore.visits, registry: .shared
        )
    }

    private var passportProgress: [HoodProgress] {
        PassportComposition.progress(hoods: hoods, places: placeCatalog.allPlaces, visits: visitedPlacesStore.visits)
    }

    /// search-quick-filters TRD §4.9 — a computed property, not stored
    /// state: it reads `searchSession`/`searchIndex` fresh on every render
    /// pass, so the result list and the map dim can never go out of step
    /// with each other or with a stale query.
    private var searchResults: [SearchResult] {
        SearchQuery.run(searchSession.text, filter: searchSession.filter, in: searchIndex)
    }

    /// search-quick-filters TRD §4.10 — `nil` whenever `.search` isn't
    /// presented (this half of the rule) or the result set is empty
    /// (`SearchDim`'s own half).
    private var searchEmphasis: (places: Set<Place.ID>, hoods: Set<Hood.ID>)? {
        guard chrome.presented == .search else { return nil }
        return SearchDim.emphasis(results: searchResults)
    }

    @Environment(\.scenePhase) private var scenePhase
    // C15 (TRD §11, `PAS-51` finding 1): read as the identity fallback for
    // `UITestOverrides.dynamicTypeSize` below, so a normal launch (no
    // `-uiTestDynamicTypeSize` argument) re-applies the same value the
    // environment already carries — a no-op — rather than this file
    // inventing a second default that could drift from SwiftUI's own.
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                hoodLayers
                // T-033: the minimal pin layer (TRD §1.2, §4.5, D5). Tapping
                // the annotation's own button calls `openPlace` directly;
                // `handleTap`'s `SpatialTapGesture` path below can call it
                // again for the same physical tap — `DetailRouter.openPlace`
                // is idempotent, so both paths landing is safe (TRD §4.5).
                //
                // Gated on `showsNames` — the same close-zoom threshold
                // `HoodLayer`'s name label and `HoodButton` already use, per
                // TRD §3.3/§8 D5 ("pins render at close zoom only"). No
                // separate pin threshold exists to tune yet, so this reuses
                // the one gate already wired to the camera rather than
                // inventing a second one (qa T-033/PAS-13 bug 2 fix).
                if showsNames {
                    ForEach(placeCatalog.allPlaces) { place in
                        PlaceLayer(
                            place: place,
                            isListed: PlacesListComposition.isListed(
                                place.id, saved: savedPlacesStore.savedPlaceIDs, visits: visitedPlacesStore.visits
                            ),
                            isDimmed: isPlaceDimmed(place)
                        ) { detailRouter.openPlace(place) }
                    }
                }
                // T-034: live events (TRD §2.3, §4.5). Not gated on
                // `showsNames` — unlike place pins, there are at most 12
                // events in the entire city (the cap, §4.4), so the layer
                // renders at every zoom (D2). Drawn after place pins, so an
                // event marker sitting on a place pin is the one the eye and
                // the finger reach. Gated only on the layer-visibility
                // toggle (§4.8, PRD req 6).
                if eventStore.isLayerVisible {
                    ForEach(visibleEvents) { event in
                        EventLayer(event: event) { detailRouter.openEvent(event) }
                    }
                }
                // scenic-walk (T-057): the two route polylines, drawn on the
                // main map behind the sheet (TRD §1.2, §4.9, D9). Absent
                // whenever no place's route has resolved.
                if let fastAndScenicPlans {
                    RouteLayer(
                        fast: fastAndScenicPlans.fast, scenic: fastAndScenicPlans.scenic,
                        selection: routePreviewModel?.selection ?? .fast
                    )
                }
                // Bound to authorization status, never to a tap (§8 D2) — the
                // mockup's unconditional marker on a near-me tap while
                // `.notDetermined` is a mockup bug, not a build target.
                if locationStore.authorizationStatus == .authorizedWhenInUse
                    || locationStore.authorizationStatus == .authorizedAlways {
                    UserAnnotation()
                }
            }
            .onAppear { ColdOpenSignpost.endIfNeeded() }
            .onMapCameraChange { context in
                zoomTier = MapZoomTier.tier(forLatitudeDelta: context.region.span.latitudeDelta)
                cameraCenterPoint = MKMapPoint(context.region.center)
                if Self.isExposingCameraRegionForTests {
                    cameraRegionDump = Self.regionDump(context.region)
                }
            }
            .simultaneousGesture(
                // FB19394663 (iOS 26 known issue): `.onTapGesture` does not
                // fire on `Map`. `SpatialTapGesture` via `.simultaneousGesture`
                // — not `.gesture` — is the workaround, so MapKit's own
                // pan/pinch handling stays live (ios-developer trd-review
                // build note, T-031; not a TRD amendment, an implementation
                // choice isolated entirely to this one modifier).
                SpatialTapGesture()
                    .onEnded { value in handleTap(at: value.location, proxy: proxy) }
            )
            // Design fix (2026-08-04): a Hood's border glow on hover.
            // `onContinuousHover` only ever fires from a trackpad/Pointer
            // device (iPad/Mac idiom) — never from touch — so this is a
            // silent no-op on iPhone and in every existing UI test.
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    handleHover(at: location, proxy: proxy)
                case .ended:
                    hoveredHoodID = nil
                }
            }
        }
        .ignoresSafeArea()
        // scenic-walk (T-057, TRD §4.9, A3): the full-screen height the
        // camera fit reasons about — measured here because this is the view
        // `.ignoresSafeArea()` just expanded to fill the screen, not assumed
        // from a device idiom. Routed through `measuringHeight` (defined
        // below `body`), not an inline `.onGeometryChange` — this modifier
        // chain was already at the type-checker's patience limit before
        // this feature, and an inline generic call here reintroduced
        // "unable to type-check this expression in reasonable time."
        .measuringHeight { newHeight in mapViewportHeight = newHeight }
        .overlay(alignment: .top) {
            ColdOpenTitle(onFadeComplete: { permissionPrompt?.titleDidFinishFading() })
                .padding(.top, 56)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            // T-078/`PAS-60` reopened (`nav-row-v2-redesign.md` §2):
            // `NearMeButton` relocated here from `MapNavRow`, stacked above
            // `CachedDataIndicator` — both are top-trailing chrome and need
            // to coexist. Apple/Google-Maps-style placement, per Aviran's
            // explicit top-right instruction.
            VStack(alignment: .trailing, spacing: 8) {
                NearMeButton(authorizationStatus: locationStore.authorizationStatus, action: handleNearMeTap)
                if densityStore.source == .cache {
                    CachedDataIndicator()
                }
            }
            .padding()
        }
        .overlay {
            // UI-test-only (see `isExposingCameraRegionForTests` above) —
            // never present in a real launch. `selectedHourDebugDump` is
            // the same seam's other half: §9 row 7e's pass condition needs
            // both "camera unchanged" and "selectedHour moved" observable
            // from the same XCUITest process.
            if Self.isExposingCameraRegionForTests {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("cameraRegionDebugDump")
                    .accessibilityValue(cameraRegionDump)
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("selectedHourDebugDump")
                    .accessibilityValue(String(densityStore.selectedHour))
            }
        }
        .overlay {
            // z3 (TRD §2.3/D3): the tap-catcher, `.search`-only in this
            // tree today. Opacity 0, still hit-testing — keeps tap-outside
            // dismissal and stops a stray map tap opening a Hood sheet
            // underneath the surface. The visual job (a scrim) is handed to
            // the selective dim at z0 instead: req 4 needs the *matches* to
            // stay visible, which a uniform scrim would also darken (§2.3).
            if chrome.presented == .search {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissSearch() }
                    // VoiceOver dismisses via the ✕ button or the standard
                    // two-finger scrub gesture instead of this invisible,
                    // full-screen catcher (ios-code-reviewer trd-review
                    // finding, folded in at build rather than left as a
                    // follow-up).
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .leading) {
            // z1 (`EdgeHint`) + z2 (`EdgeHourZone`) for the leading edge,
            // combined into one per-edge layer function (TRD §2.3, §4.8,
            // §4.9). `EdgeHourTrack` (z6) also lives here rather than at
            // its own later position in this chain — it only renders while
            // `edgeDrag` is non-nil, which can only happen while
            // `EdgeHourZone` is actually in the hierarchy, which itself
            // requires nothing to be presented (§4.10) — so z6 and z5 are
            // mutually exclusive by construction and their relative
            // position in this modifier chain has no visible effect.
            edgeLayer(for: .leading)
        }
        .overlay(alignment: .trailing) {
            edgeLayer(for: .trailing)
        }
        .overlay(alignment: .bottom) {
            // Non-icon chrome only (T-032 TRD §2.3, amended PAS-42
            // 2026-08-04): `HoodButton` (variable-width name capsule) and
            // `SettingsHint` (variable-width text) still fade to invisible
            // and stop accepting taps while any `NavSurface` is presented —
            // that part of D1's original reasoning is untouched. What used
            // to share this VStack — `NearMeButton`/`PlacesButton` — moved
            // into `MapNavRow` below; see that type's header comment for why
            // the row itself no longer fades. Reduce Motion honoured via the
            // same `withAnimation` that already governs
            // `settingsHintVisible`'s own fade.
            VStack(spacing: 8) {
                if settingsHintVisible {
                    SettingsHint()
                        .transition(.opacity)
                }
                if showsNames, let nearestHood {
                    HoodButton(hoodName: nearestHood.name) {
                        detailRouter.openHood(nearestHood)
                    }
                }
            }
            .padding(.bottom, 96)
            .opacity(chrome.isPresenting ? 0 : 1)
            .allowsHitTesting(!chrome.isPresenting)
        }
        .overlay {
            // z5 (TRD §2.4/§4.5). Above the remaining fading chrome
            // (`HoodButton`/`SettingsHint`, PAS-42), below Site A's overlay
            // (T-079/`PAS-73` re-fix: Site A moved off `.sheet()` to a
            // plain `.overlay` placed later in `body`'s modifier chain, so
            // it's "below Site A" by code order now, not by a `.sheet`'s
            // always-on-top presentation layer — moot in practice either
            // way, since D8 presentation exclusivity means `chrome.presented`
            // and `detailRouter`'s destinations are never both active at
            // once).
            if chrome.presented == .places {
                PlacesListOverlay(
                    entries: placesListEntries,
                    onSelect: { place in detailRouter.openPlace(place) },
                    onDismiss: { chrome.dismiss() }
                )
            } else if chrome.presented == .profile {
                // T-037: passport TRD §4.6, §11 C11. No `onSelect` — no
                // sticker and no Hood row is tappable in V1 (D10), so unlike
                // `.places` there is no path from here into a depth-1 modal.
                PassportSurface(
                    stickers: passportStickers,
                    progress: passportProgress,
                    isOverallLocal: PassportComposition.isOverallLocal(passportProgress),
                    onDismiss: { chrome.dismiss() }
                )
            } else if chrome.presented == .search {
                // search-quick-filters TRD §4.7, §2.3. Two heights (D2), own
                // drag handle, opaque `Color("Surface")` — the z3 tap-catcher
                // above is a separate layer, not part of this view.
                //
                // T-078/`PAS-60` reopened: also carries the Hour segment
                // (formerly `HeatModalCard`) — same `selectedHourBinding`/
                // `currentReadout` this screen already fed to it.
                SearchOverlay(
                    session: searchSession,
                    results: searchResults,
                    selectedHour: selectedHourBinding,
                    hourReadout: currentReadout,
                    onSelect: handleSearchResultSelection,
                    onDismiss: dismissSearch
                )
            }
        }
        .overlay(alignment: .bottom) {
            // z7 (TRD §2.3): always visible, always hit-testable, never
            // covered by this file's own z3/z4/z5 layers — drawn last among
            // this file's overlays so it renders above all of them. 3 icon
            // buttons (T-078/`PAS-60` reopened, down from PAS-42's 5) — see
            // `MapNavRow`'s header comment for the full history.
            MapNavRow(
                isSearchPresented: chrome.presented == .search,
                onSearchTap: handleSearchButtonTap,
                isPassportPresented: chrome.presented == .profile,
                onProfileTap: openPassport,
                onPlacesTap: openPlacesList
            )
            .padding(.bottom, 32)
        }
        .overlay(alignment: .bottom) {
            // Site A (TRD §4.2), no longer a `.sheet` (T-079/`PAS-73`
            // re-fix, `product` REJECT 2026-08-07): on iOS 26 a system
            // `.sheet()` renders as a floating card rounded on all 4
            // corners at every detent, including `.large` — not this app's
            // required flush/full-width/top-corners-only shape (measured
            // directly, not assumed; see `EventDetailModal`'s doc comment).
            // `EventDetailModal`/`PlaceDetailModal`/`HoodSheet` now each own
            // their own scrim/card presentation, so this is a plain
            // `.overlay` — placed *after* z7's `MapNavRow` above, in the
            // same position a `.sheet` used to occupy in this chain, so it
            // still renders above the nav row and covers it exactly like
            // before: this fix changes card shape/anchoring only, not
            // whether the nav row stays reachable while a Site A
            // destination is open (that's unrelated, pre-existing
            // behavior, not something this pass was asked to change).
            // Content switched between the 3 destinations rather than 3
            // separate overlays, same reason it was one `.sheet` before —
            // `depth1SheetContent()` (below `body`) is unchanged in that
            // respect, only its own call site changed.
            depth1SheetContent()
        }
        .task {
            permissionPrompt = PermissionPrompt(locationStore: locationStore)
        }
        .task {
            // scenic-walk (T-057, TRD §4.4, A2): one instance for the app's
            // lifetime, sharing this screen's own `locationStore` and
            // `routeMemoStore` — populated here rather than at `@State`
            // default-value time because a property initializer can't
            // reference another stored property on `self` (same reason
            // `permissionPrompt` above is `Optional` and set in a `.task`).
            routePreviewModel = RoutePreviewModel(
                provider: MapKitWalkingRouteProvider(), memo: routeMemoStore, locationStore: locationStore
            )
        }
        .task {
            await loadHoods()
        }
        .task {
            await densityStore.load()
        }
        .task {
            await placeCatalog.load()
        }
        .task {
            await savedPlacesStore.load()
        }
        .task {
            await visitedPlacesStore.load()
        }
        .task {
            await eventStore.load(anchorHour: densityStore.anchorHour)
        }
        .task {
            // Sequenced in one `.task` (not two independent modifiers) —
            // `start()` must not race `loadPersistedState()`, since it reads
            // state the load populates.
            await localQACoordinator.loadPersistedState()
            await localQACoordinator.start()
        }
        .onChange(of: localQACoordinator.toastState) { _, _ in
            // The passthrough window is UIKit, not SwiftUI state — it's kept
            // in sync explicitly here rather than being a view in this
            // hierarchy at all (tourist-trap-flag TRD §8 D4).
            localQAPresenter.update(coordinator: localQACoordinator)
        }
        .onChange(of: chrome.presented) { oldValue, newValue in
            // D8: leaving `.places` — by any path, including a switch to
            // another surface — must not strand a place modal that was only
            // reachable because the list was open underneath it. Same
            // `.onChange` also covers leaving `.search` by any path
            // (search-quick-filters TRD §4.9/D11) — see the function body.
            Self.handlePresentedSurfaceChange(from: oldValue, to: newValue, router: detailRouter)
        }
        .onChange(of: hoods) { _, _ in rebuildSearchIndex() }
        .onChange(of: placeCatalog.allPlaces) { _, _ in rebuildSearchIndex() }
        .onChange(of: scenePhase) { _, newPhase in
            permissionPrompt?.isSceneActive = (newPhase == .active)
            if newPhase == .active {
                Task {
                    await densityStore.refreshIfHourRolled()
                    // T-034 TRD §4.6: reuses `densityStore.anchorHour` as the
                    // "did the hour roll" signal rather than a second timer —
                    // `EventStore.refresh` is a no-op unless it actually
                    // changed, so a foreground that doesn't cross an hour
                    // boundary makes no second request.
                    await eventStore.refresh(anchorHour: densityStore.anchorHour)
                }
            }
            if newPhase == .background {
                // scenic-walk (T-057, TRD §4.7): the session memo's only
                // invalidation, from the same hook `densityStore`/
                // `eventStore` already use, not a second observer.
                routeMemoStore.clearAll()
            }
        }
        .onChange(of: routePreviewModel?.preview) { _, newPreview in
            // scenic-walk (T-057, TRD §4.9): fit the camera on the
            // transition into `.resolved` — never on a route-control tap,
            // which changes `selection`, not `preview`. A fresh `.resolved`
            // means a fresh sheet presentation, so this is also the reset
            // point for the one-time re-fit gate (A3): if the sheet's real
            // height hasn't been measured yet, this first fit uses zero
            // inset, and `presentedSheetHeight`'s own `onChange` below fires
            // the single permitted re-fit once a real height arrives.
            guard case .resolved = newPreview else { return }
            hasFitWithMeasuredSheetHeight = false
            fitCameraToResolvedRoute()
        }
        .onChange(of: presentedSheetHeight) { _, newHeight in
            // The one re-fit A3 permits: only while the current preview is
            // still `.resolved` (a route to fit), only once per
            // presentation (`hasFitWithMeasuredSheetHeight` gates it), and
            // only once a real height has actually arrived — not on the
            // initial 0 the `@State` default already fired against.
            guard case .resolved = routePreviewModel?.preview, !hasFitWithMeasuredSheetHeight, newHeight > 0 else { return }
            fitCameraToResolvedRoute()
        }
        .onChange(of: detailRouter.isDepth1Presented.wrappedValue) { wasPresented, isPresented in
            // Closing the sheet invalidates the height it just reported —
            // otherwise the next place's first fit would silently reuse a
            // stale measurement from whatever was presented before it.
            if wasPresented, !isPresented {
                presentedSheetHeight = 0
                hasFitWithMeasuredSheetHeight = false
            }
        }
        .onChange(of: locationStore.authorizationStatus) { oldStatus, newStatus in
            // Recenter on the *transition* into an authorized state, not on
            // every status value — this is the auto-scheduled system-prompt
            // path (PermissionPrompt fires without a near-me tap), so nothing
            // else reacts to a grant unless we do it here (qa T-031 Finding
            // A). `isNewGrant` fires exactly once per grant and never again
            // for e.g. `.authorizedWhenInUse` -> `.authorizedAlways`,
            // matching the same one-shot camera set `handleNearMeTap` does on
            // its own authorized branch below.
            guard Self.isNewGrant(from: oldStatus, to: newStatus) else { return }
            camera = .userLocation(fallback: .region(Self.telAvivCityWide))
        }
        // C15 (TRD §11, `PAS-51` finding 1) — last in the chain so it
        // applies to this whole subtree, including `SearchOverlay`'s Hour
        // segment and `MapNavRow`. `UITestOverrides.dynamicTypeSize` is `nil` on a
        // normal launch, in which case this re-applies
        // `systemDynamicTypeSize` — the value already in effect — so a real
        // launch is unaffected.
        .environment(\.dynamicTypeSize, UITestOverrides.dynamicTypeSize ?? systemDynamicTypeSize)
    }

    /// True exactly when a status change represents a first-time grant
    /// (denied/restricted/notDetermined -> authorized*), as opposed to a
    /// lateral move between two already-authorized states or a re-render with
    /// no actual change. Pulled out as a pure, static predicate so the
    /// recenter-on-grant fix (qa T-031 Finding A) has a fast unit test
    /// instead of relying only on a manual simctl repro.
    static func isNewGrant(from oldStatus: CLAuthorizationStatus, to newStatus: CLAuthorizationStatus) -> Bool {
        let wasAuthorized = oldStatus == .authorizedWhenInUse || oldStatus == .authorizedAlways
        let isAuthorized = newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways
        return !wasAuthorized && isAuthorized
    }

    // MARK: - scenic-walk (T-057) camera fit (TRD §4.9, amendment A3) —
    // `fittedRegion`/`visibleAboveSheetFraction` are pure, testable static
    // functions over plain values, same construction as `isNewGrant` above.
    // `fitCameraToResolvedRoute` is the one instance method that reads this
    // screen's own measured state and calls them.

    /// The fraction of the screen left visible above the presented sheet,
    /// derived from two **measured** heights (§9 row 12c requires this —
    /// no device-specific pixel constant anywhere in this path). `nil`
    /// before either height has been reported by `onGeometryChange`, which
    /// `fittedRegion` reads as "fit with zero inset" (A3's stated edge
    /// case: a resolve completing before first layout).
    nonisolated static func visibleAboveSheetFraction(mapViewportHeight: CGFloat, presentedSheetHeight: CGFloat) -> Double? {
        guard mapViewportHeight > 0, presentedSheetHeight > 0 else { return nil }
        let visible = 1 - Double(presentedSheetHeight / mapViewportHeight)
        // Clamped, not asserted: a sheet momentarily taller than the
        // viewport (a transient layout pass) must not invert the fit.
        return max(0.05, min(1.0, visible))
    }

    /// Fits the union of both polylines' bounding rects into the region
    /// visible above the presented sheet (TRD §4.9) — the union sits in the
    /// top `visibleAboveSheetFraction` of a taller region, not centred in
    /// the full one, so it never renders under the sheet. `visibleAboveSheetFraction
    /// == nil` (no measured heights yet) fits with zero inset — the whole
    /// region, no reserved space — rather than guessing a fraction. `nil`
    /// when there are no coordinates to fit (never called with an empty
    /// fast route in practice, since `.resolved` always carries one, but
    /// this is a system boundary — a malformed response — not an internal
    /// invariant).
    nonisolated static func fittedRegion(
        fastCoordinates: [CLLocationCoordinate2D],
        scenicCoordinates: [CLLocationCoordinate2D],
        visibleAboveSheetFraction: Double?
    ) -> MKCoordinateRegion? {
        let allPoints = (fastCoordinates + scenicCoordinates).map(MKMapPoint.init)
        guard !allPoints.isEmpty else { return nil }

        let xs = allPoints.map(\.x)
        let ys = allPoints.map(\.y)
        let unionRect = MKMapRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        var region = MKCoordinateRegion(unionRect)

        // Breathing room around the route itself, before the sheet inset.
        region.span.latitudeDelta *= 1.3
        region.span.longitudeDelta *= 1.3

        guard let fraction = visibleAboveSheetFraction else { return region }

        // Bottom inset: expand the visible latitude span so the (padded)
        // route occupies only the top `fraction` of it, then shift the
        // centre south so the route stays in the top fraction rather than
        // the middle of the taller region.
        let requiredLatDelta = region.span.latitudeDelta / fraction
        let extraLatDelta = requiredLatDelta - region.span.latitudeDelta
        region.center.latitude -= extraLatDelta / 2
        region.span.latitudeDelta = requiredLatDelta

        return region
    }

    /// Reads this screen's own measured state and performs one fit. Called
    /// from two triggers (see the `.onChange` pair above): the transition
    /// into `.resolved`, and — if the sheet's real height wasn't known yet
    /// at that point — once more when it arrives.
    private func fitCameraToResolvedRoute() {
        guard case .resolved(let fast, let scenicResult) = routePreviewModel?.preview else { return }
        let scenicCoordinates = (try? scenicResult.get())?.coordinates ?? []
        let fraction = Self.visibleAboveSheetFraction(
            mapViewportHeight: mapViewportHeight, presentedSheetHeight: presentedSheetHeight
        )
        if fraction != nil {
            hasFitWithMeasuredSheetHeight = true
        }
        if let region = Self.fittedRegion(
            fastCoordinates: fast.coordinates, scenicCoordinates: scenicCoordinates, visibleAboveSheetFraction: fraction
        ) {
            camera = .region(region)
        }
    }

    // MARK: - places-been-saved (T-036) presentation wiring — pure/testable,
    // same construction as `isNewGrant` above: the side effect lives in a
    // static function over the two objects it touches, so §9 row 8(b)/(c)
    // are unit-tested directly rather than through `.onChange`/button-tap
    // plumbing that needs a live SwiftUI environment to exercise.

    /// `PlacesButton`'s action (TRD §2.4, §4.6, D8, flow §5 "Open the
    /// list"). Closing the Hood sheet first stops a tap presenting the list
    /// *underneath* a still-open Site A destination (T-079/`PAS-73` re-fix:
    /// no longer literally a system sheet, but still a layer that renders
    /// above z5 and can never be reached from underneath it — see that
    /// overlay's own comment), in a layer that can never be reached.
    ///
    /// **Guarded against re-tap-while-open (PAS-42, 2026-08-04).** Before
    /// the nav-row merge this was protected by `PlacesButton` fading to
    /// non-hit-testable whenever `.places` was presented (D7); now that the
    /// button never fades (`MapNavRow`'s header comment), the same
    /// protection has to live here instead — a true no-op, not a
    /// `chrome.toggle` that would close the list, so re-tapping the button
    /// while its own list is open does nothing (the three other dismissal
    /// paths on the list itself — ✕, drag, tap-outside-scrim — are
    /// untouched and remain the only ways to close it).
    static func openPlacesList(router: DetailRouter, chrome: MapChromeState) {
        guard chrome.presented != .places else { return }
        router.closeHood()
        chrome.toggle(.places)
    }

    /// D8: leaving `.places` — by any path, including a switch to another
    /// surface — closes a stacked place modal so it can never be stranded.
    /// While `.places` is presented the scrim blocks map taps, so a depth-1
    /// place modal open at that point can only have been opened from a list
    /// row; closing the list must not leave it behind.
    ///
    /// search-quick-filters TRD §4.9/D11 folds in here too: leaving
    /// `.search` — again, by any path — calls `router.closeHood()`, which
    /// clears whichever destination a search result opened (a search can
    /// produce either a Hood or a place sheet, unlike `.places`, which only
    /// ever produces a place). The explicit dismiss paths (✕, drag,
    /// tap-outside, re-tap) already call this directly; this `.onChange`
    /// hook is the backstop for the one path those can't reach — switching
    /// straight to another nav surface without dismissing search first.
    static func handlePresentedSurfaceChange(from oldValue: NavSurface?, to newValue: NavSurface?, router: DetailRouter) {
        guard oldValue != newValue else { return }
        if oldValue == .places {
            router.closePlace()
        }
        if oldValue == .search {
            router.closeHood()
        }
    }

    private func openPlacesList() {
        Self.openPlacesList(router: detailRouter, chrome: chrome)
    }

    // MARK: - search-quick-filters (T-038) presentation wiring — same
    // construction as `openPlacesList`/`openPassport` above: pure/testable
    // static functions over the objects they touch (TRD §4.9, §9 row 1/7).

    /// The search button's action when `.search` is not yet presented.
    /// Closes any open Hood sheet first, for the same reason
    /// `openPlacesList` does: presenting the overlay with one already open
    /// would put it underneath a still-open Site A destination (same
    /// T-079/`PAS-73` re-fix note as `openPlacesList`'s identical comment),
    /// in a layer that can never be reached.
    static func openSearch(router: DetailRouter, chrome: MapChromeState) {
        router.closeHood()
        chrome.toggle(.search)
    }

    /// Every manual-dismiss path (✕, drag-past-threshold, z3 tap-outside,
    /// re-tapping the search button while open) routes through this
    /// (TRD §4.6's table, D11): `clear()` because this *is* a completion,
    /// not an interruption, and `closeHood()` because search can produce
    /// either destination and neither should outlive the surface it was
    /// opened from.
    static func dismissSearch(router: DetailRouter, chrome: MapChromeState, session: SearchSession) {
        session.clear()
        router.closeHood()
        chrome.dismiss()
    }

    private func handleSearchButtonTap() {
        if chrome.presented == .search {
            dismissSearch()
        } else {
            Self.openSearch(router: detailRouter, chrome: chrome)
            // T-078/`PAS-60` reopened: re-anchor "now" on open, same as the
            // old standalone Heat modal did on its own open (D3, §4.5 item
            // 2) — the Hour segment now folded into this same surface is
            // one tap away from the moment this fires, rather than gated on
            // a second, segment-specific open event.
            Task { await densityStore.refreshIfHourRolled() }
        }
    }

    private func dismissSearch() {
        Self.dismissSearch(router: detailRouter, chrome: chrome, session: searchSession)
    }

    /// A result "goes where the map would have gone" (TRD §9 row 5): the
    /// same `openPlace`/`openHood` calls a pin tap or a Hood-sheet row would
    /// make, preceded by `clear()` (PRD req 7 bullet 2 — selection
    /// completes the search). The Hood branch also pans the camera to fit
    /// the Hood, issued *before* `openHood` so the move is committed under
    /// the sheet rather than fighting it (§4.9).
    private func handleSearchResultSelection(_ result: SearchResult) {
        searchSession.clear()
        switch result.kind {
        case .place(let place, _):
            detailRouter.openPlace(place)
        case .hood(let hood):
            camera = .region(MKCoordinateRegion(hood.boundingRect))
            detailRouter.openHood(hood)
        }
    }

    /// Off the cold-open path (§4.9) — rebuilt from whichever catalog just
    /// changed, so the index is correct the moment both have resolved
    /// without either `.task` needing to know about the other.
    private func rebuildSearchIndex() {
        searchIndex = SearchIndex.build(places: placeCatalog.allPlaces, hoods: hoods)
    }

    /// search-quick-filters TRD §4.10 — `false` whenever there is nothing to
    /// emphasise, which is also the byte-identical-to-today case.
    private func isPlaceDimmed(_ place: Place) -> Bool {
        guard let searchEmphasis else { return false }
        return !searchEmphasis.places.contains(place.id)
    }

    private func isHoodDimmed(_ hood: Hood) -> Bool {
        guard let searchEmphasis else { return false }
        return !searchEmphasis.hoods.contains(hood.id)
    }

    /// Design fix (2026-08-04). Pulled out of the `ForEach` in `body` rather
    /// than inlined as `fill.hood.id == hoveredHoodID` — inline, it pushed
    /// the surrounding `MapContentBuilder` expression past the type
    /// checker's time limit ("unable to type-check this expression in
    /// reasonable time"); as a named function the same comparison type-checks
    /// instantly.
    private func isHoodHovered(_ hood: Hood) -> Bool {
        hood.id == hoveredHoodID
    }

    // MARK: - passport (T-037) presentation wiring — same construction as
    // `openPlacesList` above, pure/testable (TRD §4.6, §9 row 2, §11 C11).

    /// `ProfileButton`'s action (TRD §2.4, §4.6), wired into `MapNavRow`
    /// below (§11 C7) — the one call site this function's open-path
    /// plumbing was always built and tested (§9 row 2(c)) for. Closing the
    /// Hood sheet first for the same reason as `openPlacesList`: a tap must
    /// not present Passport *underneath* a still-open Site A destination
    /// (same T-079/`PAS-73` re-fix note as `openPlacesList`'s identical
    /// comment), in a layer that can never be reached. `chrome.toggle(.profile)` alone
    /// handles the re-tap-to-close case (`PassportWiringTests
    /// .openPassportTogglesClosedWhenAlreadyOpen`), so unlike search there
    /// is no separate dismiss function to route through.
    static func openPassport(router: DetailRouter, chrome: MapChromeState) {
        router.closeHood()
        chrome.toggle(.profile)
    }

    private func openPassport() {
        Self.openPassport(router: detailRouter, chrome: chrome)
    }

    // No `.profile`-leaving analogue to `handlePresentedSurfaceChange` above:
    // unlike `.places`, Passport has no tappable sticker or Hood row (D10)
    // and so structurally can never have a place modal stacked on top of it
    // — there is nothing for a leave-hook to clean up. Stated here rather
    // than left implicit, since the TRD's §4.6 restates T-036's D8 "on
    // leave, `router.closePlace()`" pattern and a future reader should not
    // assume it was missed.

    /// Off the main actor; the map renders before this resolves (§5.1, §7).
    private func loadHoods() async {
        let result = await Task.detached(priority: .userInitiated) {
            Result { try HoodCatalog.load() }
        }.value
        switch result {
        case .success(let loaded):
            hoods = loaded
            hitTester = HoodHitTester(hoods: loaded)
        case .failure(let error):
            // A corrupt bundled resource is a build defect, not a runtime
            // empty state (TRD §4.2, `passenger-code/CLAUDE.md` fail-fast) —
            // this can only happen if `hoods-tel-aviv.json` shipped malformed.
            fatalError("HoodCatalog.load() failed: \(error)")
        }
    }

    /// Event wins over place, which wins over Hood (T-034 TRD §4.5, D7): a
    /// marker drawn on top must be the one a tap reaches, and a pin always
    /// sits inside a Hood, so the reverse order would make either
    /// unreachable. A miss on all three is never a dismiss (TRD §4.2 rule 4)
    /// — it does nothing.
    ///
    /// The event branch is *not* gated on `showsNames` — events render at
    /// every zoom (D2) — but it is gated on `eventStore.isLayerVisible`,
    /// exactly the layer's own draw condition above, so tap resolution and
    /// marker rendering share one gate the same way the place branch already
    /// shares `showsNames` with the pin `ForEach`. Without this,
    /// `MapScreen.swift`'s greedy `SpatialTapGesture` would fire alongside
    /// the marker's own `Button` and, before D7, could resolve to the wrong
    /// destination for the same physical tap — `DetailRouter.openEvent` is
    /// idempotent, so both paths landing here is safe.
    ///
    /// The place branch is gated on `showsNames`, the same threshold the pin
    /// `ForEach` above is gated on — tap *resolution* and pin *rendering*
    /// have to share one gate or they silently disagree (qa T-033/PAS-13
    /// acceptance REJECT). Ungated, the live-computed `tolerance` below is
    /// large enough at the cold-open camera (~700m) that every point inside
    /// a populated Hood's real polygon falls within tolerance of one of its
    /// own places, so a tap anywhere in e.g. Florentin opened a place modal
    /// for a pin nobody could see. With the gate, a miss on the (now
    /// unreachable) place branch falls through to the Hood branch below
    /// exactly as PRD req 1's added bullet requires: at any zoom where pins
    /// aren't drawn, a tap inside a Hood opens that Hood's sheet.
    private func handleTap(at screenPoint: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
        let tapPoint = MKMapPoint(coordinate)
        let tolerance = mapPointTolerance(forScreenPoints: 22, at: screenPoint, proxy: proxy) ?? 0

        let eventHitTester = EventHitTester(events: eventStore.isLayerVisible ? visibleEvents : [])
        let placeHitTester = PlaceHitTester(places: placeCatalog.allPlaces)
        if let event = eventHitTester.event(at: tapPoint, tolerance: tolerance) {
            detailRouter.openEvent(event)
        } else if showsNames, let place = placeHitTester.place(at: tapPoint, tolerance: tolerance) {
            detailRouter.openPlace(place)
        } else if let hood = hitTester.hood(at: tapPoint, tolerance: tolerance) {
            detailRouter.openHood(hood)
        }
    }

    /// Design fix (2026-08-04): resolves the Hood under the pointer for
    /// `HoodLayer`'s hover glow. `tolerance: 0` deliberately, unlike
    /// `handleTap`'s enlarged touch target above — hover should track the
    /// pointer sitting on the drawn polygon itself, not a margin extended
    /// past it for a fingertip that doesn't apply here.
    private func handleHover(at screenPoint: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else {
            hoveredHoodID = nil
            return
        }
        hoveredHoodID = hitTester.hood(at: MKMapPoint(coordinate), tolerance: 0)?.id
    }

    /// Converts a screen-point distance into a map-point distance at the
    /// *current* camera, by sampling two nearby screen points through the live
    /// `MapProxy` and measuring their projected distance — self-correcting for
    /// zoom and Tel Aviv's latitude, rather than a value computed once and
    /// stale (named per `ios-code-reviewer`'s trd-review request that this
    /// mechanism be specified explicitly before C1/C3).
    private func mapPointTolerance(forScreenPoints screenDistance: Double, at screenPoint: CGPoint, proxy: MapProxy) -> Double? {
        guard let origin = proxy.convert(screenPoint, from: .local) else { return nil }
        let reference = CGPoint(x: screenPoint.x + screenDistance, y: screenPoint.y)
        guard let referenceCoordinate = proxy.convert(reference, from: .local) else { return nil }
        return MKMapPoint(origin).distance(to: MKMapPoint(referenceCoordinate))
    }

    /// The full authorization switch (§8 D2):
    private func handleNearMeTap() {
        switch locationStore.authorizationStatus {
        case .notDetermined:
            // Cancel the pending scheduled prompt and request immediately —
            // one prompt, ever, from either path. `.userLocation(fallback:)` is
            // a self-tracking camera-position case: once authorization
            // resolves, MapKit keeps following the user's location on its own,
            // no manual re-trigger needed on the success path.
            permissionPrompt?.requestImmediately()
            camera = .userLocation(fallback: .region(Self.telAvivCityWide))
        case .authorizedWhenInUse, .authorizedAlways:
            camera = .userLocation(fallback: .region(Self.telAvivCityWide))
        case .denied, .restricted:
            showSettingsHintTemporarily()
        @unknown default:
            showSettingsHintTemporarily()
        }
    }

    // MARK: - T-032 edge-hour gesture surface (TRD §2.3, §4.8–§4.10)

    /// One live edge's `EdgeHint`/`EdgeHourZone`/`EdgeHourTrack`, combined
    /// (TRD §2.1's module layout, §2.3's z-table). A `GeometryReader` sized
    /// to `EdgeGeometry.captureWidth` and the full screen height gives
    /// `EdgeGeometry.band(in:safeArea:)` exactly the coordinate space
    /// `EdgeHourZone`'s `DragGesture` reports touches in (§4.8's default
    /// `.local`), so no conversion is needed anywhere in this feature.
    ///
    /// **Known limitation, disclosed rather than silent:** this
    /// `GeometryReader` sits inside the same modifier chain as this file's
    /// own `.ignoresSafeArea()` (applied to the `Map` above), and every
    /// other bottom-chrome element in this file already works around the
    /// same effect by hardcoding a padding value instead of reading a live
    /// `safeAreaInsets` (`ColdOpenTitle`'s `.padding(.top, 56)`,
    /// `MapNavRow`'s `.padding(.bottom, 96)`) — `GeometryProxy
    /// .safeAreaInsets` read here may report `0` rather than the device's
    /// real inset. `EdgeGeometry.band(in:safeArea:)`'s
    /// `max(floor, safeAreaInset + clearance)` formula means this is
    /// numerically correct on every current device regardless (the floor
    /// already equals the real worst-case inset + clearance, TRD §4.9 D8),
    /// but D8's own stated purpose — staying correct automatically on a
    /// *future* device with a larger inset — is not verified end-to-end
    /// here. Flagged for `ios-code-reviewer`/`qa` to confirm on a device
    /// with a non-floor safe area, rather than assumed.
    @ViewBuilder
    private func edgeLayer(for edge: HorizontalEdge) -> some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let idiom = UIDevice.current.userInterfaceIdiom
            let isAnySheetPresented = detailRouter.isDepth1Presented.wrappedValue
            let liveEdges = EdgeAvailability.liveEdges(
                idiom: idiom,
                isPortrait: isPortrait,
                isAnySurfacePresented: chrome.isPresenting,
                isAnySheetPresented: isAnySheetPresented
            )
            let band = EdgeGeometry.band(in: geometry.size, safeArea: geometry.safeAreaInsets)
            let midY = (band.lowerBound + band.upperBound) / 2

            ZStack(alignment: .topLeading) {
                if liveEdges.contains(edge) {
                    if edgeDrag == nil {
                        EdgeHint(edge: edge, band: band)
                            .position(x: EdgeGeometry.captureWidth / 2, y: midY)
                    }
                    EdgeHourZone(
                        edge: edge,
                        band: band,
                        selectedHour: selectedHourBinding,
                        activeDrag: $edgeDrag,
                        onTouchDown: {
                            Task { await densityStore.refreshIfHourRolled() }
                        }
                    )
                } else if edge == .trailing, idiom == .pad, !chrome.isPresenting, !isAnySheetPresented {
                    // iPad's right edge is permanently excluded (system
                    // Slide Over, Q2) — a ghost mark explains the absence
                    // rather than reading as a missed build (§4.11).
                    EdgeHintGhostMark()
                        .position(x: EdgeGeometry.captureWidth / 2, y: midY)
                }

                if let edgeDrag, edgeDrag.edge == edge {
                    EdgeHourTrack(state: edgeDrag, band: band, readout: currentReadout)
                }
            }
        }
        .frame(width: EdgeGeometry.captureWidth)
    }

    /// Site A's overlay content (TRD §4.2) — pulled out of the inline
    /// closure above for the type-checker reason stated there. No longer a
    /// `.sheet`'s content (T-079/`PAS-73` re-fix, `product` REJECT
    /// 2026-08-07 — see `body`'s `.overlay` comment), but the explicit
    /// `.environment()` re-application below is left in place rather than
    /// relied-on-by-inheritance: this is the exact spot qa's T-033/PAS-13
    /// crash traced to once (a `.sheet`'s content closure doesn't inherit
    /// `.environment(_:)` set on the presenting view, even from the
    /// "textbook" position earlier in the same chain), and while a plain
    /// `.overlay` doesn't have that specific hazard — normal view embedding
    /// does inherit environment — re-deriving that from first principles
    /// every time this file is read is worse than one redundant, cheap
    /// re-application. `HoodSheet`'s own embedded `PlaceDetailModal` (Site
    /// B, depth 2) does the same, for the same reason — see its own
    /// comment.
    ///
    /// scenic-walk (T-057): `routePreviewModel` is populated by the `.task`
    /// in `body`, essentially immediately — before any tap could open this
    /// sheet. Guarding with `if let` rather than force-unwrapping keeps
    /// that an observed precondition instead of an assumed one; a sheet
    /// opened in the one-frame gap before the `.task` runs simply renders
    /// without route controls, and `PlaceDetailModal`'s own
    /// `.noOrigin`/`.failed` fallback (unset `RoutePreviewModel` reads the
    /// same as "not yet resolved") covers the rest.
    @ViewBuilder
    private func depth1SheetContent() -> some View {
        if let routePreviewModel {
            Group {
                if let hood = detailRouter.hood {
                    HoodSheet(hood: hood, hoods: hoods)
                } else if let place = detailRouter.place {
                    PlaceDetailModal(place: place, hoods: hoods)
                } else if let event = detailRouter.event {
                    // T-034 TRD §4.7, D6: a third depth-1 destination, not a
                    // second `.sheet`. `EventDetailModal` is handed the
                    // event by value and needs no new environment injection.
                    // `hoodName` (T-052/PAS-40) is resolved here, once, off
                    // the `hoods` list this screen already loaded — a plain
                    // value lookup, not a new environment dependency.
                    EventDetailModal(event: event, hoodName: hoods.first(where: { $0.id == event.hoodID })?.name)
                }
            }
            .environment(placeCatalog)
            .environment(detailRouter)
            .environment(savedPlacesStore)
            .environment(routePreviewModel)
            // No `.presentationBackgroundInteraction` here (T-079/`PAS-73`
            // re-fix, `product` REJECT 2026-08-07) — that API only applies
            // to a real `.sheet()`, and this is a plain `.overlay` now (see
            // this property's own call site in `body`). It used to read
            // `.enabled(upThrough: .medium)`; a custom overlay has no
            // system-managed "interact with what's behind" concept at all —
            // the card is opaque and fully covers the map behind it by
            // construction, same net effect, just via a different
            // mechanism (this is not a functional regression).
            // scenic-walk (T-057, TRD §4.9, A3): the overlay's own rendered
            // height, published up to `MapScreen` rather than assumed —
            // this is what makes the camera's bottom inset track Dynamic
            // Type and size class instead of a fixed constant (§9 row 12).
            .measuringHeight { newHeight in presentedSheetHeight = newHeight }
        }
    }

    private func showSettingsHintTemporarily() {
        settingsHintDismissTask?.cancel()
        withAnimation { settingsHintVisible = true }
        settingsHintDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { settingsHintVisible = false }
        }
    }
}

// scenic-walk (T-057, TRD §4.9, A3): a monomorphized wrapper around
// `onGeometryChange(for:of:action:)`, called from two points inside
// `MapScreen.body`'s modifier chain. That chain was already at the Swift
// type-checker's patience limit before this feature — inlining the generic
// `onGeometryChange` call directly reintroduced "unable to type-check this
// expression in reasonable time" (a real build failure, not a style
// preference). A fully-typed helper gives the compiler a monomorphic call
// site to resolve instead of one more term in the giant chain's inference.
private extension View {
    func measuringHeight(action: @escaping (CGFloat) -> Void) -> some View {
        onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: action)
    }
}
