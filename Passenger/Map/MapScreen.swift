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

    /// Below this span, a Hood is large enough on screen for its name label to
    /// be legible (design spec §2 — "Hood zoom and closer only").
    private static let nameLabelSpanThreshold: Double = 0.06

    @State private var camera: MapCameraPosition = .region(telAvivCityWide)
    @State private var hoods: [Hood] = []
    @State private var hitTester = HoodHitTester(hoods: [])
    @State private var showsNames = false
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

    /// The Hood whose polygon contains the camera's centre right now, or
    /// `nil` between Hoods — `HoodButton` hides itself in that gap rather
    /// than naming the nearest one by distance (TRD §4.7).
    private var nearestHood: Hood? {
        hitTester.hood(at: cameraCenterPoint, tolerance: 0)
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                ForEach(hoods) { hood in
                    HoodLayer(
                        hood: hood,
                        band: densityStore.band(for: hood.id, hour: densityStore.selectedHour),
                        showsName: showsNames
                    )
                }
                // T-033: the minimal pin layer (TRD §1.2, §4.5, D5). Tapping
                // the annotation's own button calls `openPlace` directly;
                // `handleTap`'s `SpatialTapGesture` path below can call it
                // again for the same physical tap — `DetailRouter.openPlace`
                // is idempotent, so both paths landing is safe (TRD §4.5).
                ForEach(placeCatalog.allPlaces) { place in
                    PlaceLayer(place: place) { detailRouter.openPlace(place) }
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
                showsNames = context.region.span.latitudeDelta < Self.nameLabelSpanThreshold
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
                // Bucket-2 chrome once T-032 ships a nav-row modal to hide
                // behind (TRD §4.7) — no such state exists in this codebase
                // yet (T-032 is still in `design`), so there is nothing to
                // condition that on today; not fabricated ahead of it.
                if showsNames, let nearestHood {
                    HoodButton(hoodName: nearestHood.name) {
                        detailRouter.openHood(nearestHood)
                    }
                }
                NearMeButton(authorizationStatus: locationStore.authorizationStatus, action: handleNearMeTap)
            }
            .padding(.bottom, 32)
        }
        .environment(placeCatalog)
        .environment(detailRouter)
        .environment(savedPlacesStore)
        .sheet(isPresented: detailRouter.isDepth1Presented) {
            // Site A (TRD §4.2): one `.sheet` modifier, content switched
            // rather than two sheets attached to the same view.
            Group {
                if let hood = detailRouter.hood {
                    HoodSheet(hood: hood)
                } else if let place = detailRouter.place {
                    PlaceDetailModal(place: place)
                }
            }
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
        .onChange(of: scenePhase) { _, newPhase in
            permissionPrompt?.isSceneActive = (newPhase == .active)
            if newPhase == .active {
                Task { await densityStore.refreshIfHourRolled() }
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

    /// Place wins over Hood: a pin always sits inside a Hood, so the reverse
    /// order would make a pin unreachable (TRD §4.5). A miss on both is
    /// never a dismiss (TRD §4.2 rule 4) — it does nothing.
    private func handleTap(at screenPoint: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
        let tapPoint = MKMapPoint(coordinate)
        let tolerance = mapPointTolerance(forScreenPoints: 22, at: screenPoint, proxy: proxy) ?? 0

        let placeHitTester = PlaceHitTester(places: placeCatalog.allPlaces)
        if let place = placeHitTester.place(at: tapPoint, tolerance: tolerance) {
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
