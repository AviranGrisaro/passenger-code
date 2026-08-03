import CoreLocation
import MapKit
import SwiftUI

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

    @State private var camera: MapCameraPosition = .region(initialCameraRegion)
    @State private var hoods: [Hood] = []
    @State private var hitTester = HoodHitTester(hoods: [])
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

    @State private var densityStore = DensityStore()
    @State private var locationStore = LocationStore()
    @State private var permissionPrompt: PermissionPrompt?

    // T-033: place/Hood detail (TRD §2.1). One session-scoped catalog, one
    // router, read by both sheets and the pin layer — no per-sheet fetch.
    @State private var placeCatalog = PlaceCatalog()
    @State private var savedPlacesStore = SavedPlacesStore()
    @State private var detailRouter = DetailRouter()

    // places-been-saved (T-036): the second provenance source (§3.1) and the
    // one-surface-at-a-time chrome state T-032 owns (§2.2) — created here
    // because no other build order landed it first in this working tree; if
    // T-032's own C1 lands later it finds `MapChromeState.swift` already
    // correct and adds nothing to it.
    @State private var visitedPlacesStore = VisitedPlacesStore()
    @State private var chrome = MapChromeState()

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

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                ForEach(hoods) { hood in
                    HoodLayer(
                        hood: hood,
                        band: densityStore.band(for: hood.id, hour: densityStore.selectedHour),
                        zoomTier: zoomTier
                    )
                }
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
                            )
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
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            ColdOpenTitle(onFadeComplete: { permissionPrompt?.titleDidFinishFading() })
                .padding(.top, 56)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if densityStore.source == .cache {
                CachedDataIndicator()
                    .padding()
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if settingsHintVisible {
                    SettingsHint()
                        .transition(.opacity)
                }
                // The second door to a Hood's detail sheet (TRD §1.2, §4.7),
                // visible at exactly the zoom `showsNames` already gates.
                // Bucket-2 chrome once T-032's own build wires this button
                // into the `chrome`/fade mechanism `MapChromeState` now
                // provides (TRD §4.7) — out of scope for this file's own
                // task, so not fabricated ahead of it here.
                if showsNames, let nearestHood {
                    HoodButton(hoodName: nearestHood.name) {
                        detailRouter.openHood(nearestHood)
                    }
                }
                HStack(spacing: 16) {
                    NearMeButton(authorizationStatus: locationStore.authorizationStatus, action: handleNearMeTap)
                    // Bucket-2 chrome (TRD §2.4, D7) — fades with the rest of
                    // this cluster whenever any `NavSurface` is presented, so
                    // it cannot be re-tapped to dismiss its own open list
                    // (accepted cost, D7).
                    PlacesButton(isFaded: chrome.isPresenting, action: openPlacesList)
                }
            }
            .padding(.bottom, 32)
        }
        .overlay {
            // z5 (TRD §2.4/§4.5). Above bucket-2 chrome, below the system
            // sheet at Site A — a `.sheet` always presents above the whole
            // hierarchy regardless of modifier order.
            if chrome.presented == .places {
                PlacesListOverlay(
                    entries: placesListEntries,
                    onSelect: { place in detailRouter.openPlace(place) },
                    onDismiss: { chrome.dismiss() }
                )
            }
        }
        .sheet(isPresented: detailRouter.isDepth1Presented) {
            // Site A (TRD §4.2): one `.sheet` modifier, content switched
            // rather than two sheets attached to the same view.
            //
            // `.environment()` is applied to *this* Group — the sheet's own
            // content — not to the presenting view above (where it lived
            // before qa's T-033/PAS-13 crash report). Root cause: `.sheet`'s
            // content closure does not inherit `.environment(_:)` values set
            // on the view that hosts `.sheet`, even when those modifiers
            // appear earlier in the same chain (the "textbook" position).
            // Confirmed by direct repro: with `.environment()` applied above
            // `.sheet(...)` as it was, every tap that opened this sheet threw
            // "No Observable object of type X found" from
            // `SwiftUICore/Environment+Objects.swift`, 100% of the time, for
            // every one of `PlaceCatalog`/`DetailRouter`/`SavedPlacesStore` —
            // moving the same three calls to wrap the sheet's own content
            // (here) fixes it with no other change. `HoodSheet`'s own nested
            // `.sheet` (Site B, depth 2) needs the identical treatment for
            // the same reason — see its own comment.
            Group {
                if let hood = detailRouter.hood {
                    HoodSheet(hood: hood)
                } else if let place = detailRouter.place {
                    PlaceDetailModal(place: place)
                } else if let event = detailRouter.event {
                    // T-034 TRD §4.7, D6: a third depth-1 destination, not a
                    // second `.sheet`. `EventDetailModal` is handed the
                    // event by value and needs no new environment injection.
                    EventDetailModal(event: event)
                }
            }
            .environment(placeCatalog)
            .environment(detailRouter)
            .environment(savedPlacesStore)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .task {
            permissionPrompt = PermissionPrompt(locationStore: locationStore)
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
            // reachable because the list was open underneath it.
            Self.handlePresentedSurfaceChange(from: oldValue, to: newValue, router: detailRouter)
        }
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

    // MARK: - places-been-saved (T-036) presentation wiring — pure/testable,
    // same construction as `isNewGrant` above: the side effect lives in a
    // static function over the two objects it touches, so §9 row 8(b)/(c)
    // are unit-tested directly rather than through `.onChange`/button-tap
    // plumbing that needs a live SwiftUI environment to exercise.

    /// `PlacesButton`'s action (TRD §2.4, §4.6, D8, flow §5 "Open the
    /// list"). Closing the Hood sheet first stops a tap presenting the list
    /// *underneath* a still-open system sheet, in a layer that can never be
    /// reached.
    static func openPlacesList(router: DetailRouter, chrome: MapChromeState) {
        router.closeHood()
        chrome.toggle(.places)
    }

    /// D8: leaving `.places` — by any path, including a switch to another
    /// surface — closes a stacked place modal so it can never be stranded.
    /// While `.places` is presented the scrim blocks map taps, so a depth-1
    /// place modal open at that point can only have been opened from a list
    /// row; closing the list must not leave it behind.
    static func handlePresentedSurfaceChange(from oldValue: NavSurface?, to newValue: NavSurface?, router: DetailRouter) {
        guard oldValue == .places, newValue != .places else { return }
        router.closePlace()
    }

    private func openPlacesList() {
        Self.openPlacesList(router: detailRouter, chrome: chrome)
    }

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
