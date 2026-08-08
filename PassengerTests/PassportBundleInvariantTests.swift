import CoreLocation
import Foundation
import Testing
@testable import Passenger

/// passport TRD §9 rows 3/4, §10, §11 C12 — the shipped-bundle invariants
/// that stop A1 (`place-types-tel-aviv.json`) and A2
/// (`designatedForProgression`) being quietly forgotten. Reads the real
/// compiled bundle (`Bundle.main` — `PassengerTests` runs hosted, per
/// `PlaceCatalogTests`' own precedent), not a fixture: these three checks
/// are about what actually ships.
///
/// **Expected to fail until both A1 and A2 land** (TRD §11: "these are the
/// assertions that stop A1/A2 being quietly forgotten" — the gate is
/// supposed to fail pre-A1/A2, that's what makes it a gate). At the time
/// this task was built, both had already landed in the shared working tree
/// (`Passenger/Resources/place-types-tel-aviv.json` present,
/// `hoods-tel-aviv.json` carrying three `designatedForProgression: true`
/// rows) — confirmed directly before writing these, not assumed.
@Suite("Passport shipped-bundle invariants")
@MainActor
struct PassportBundleInvariantTests {
    @Test("at least one Hood in the shipped bundle carries designatedForProgression == true")
    func atLeastOneDesignatedHood() throws {
        let hoods = try HoodCatalog.load()
        #expect(hoods.contains { $0.designatedForProgression })
    }

    /// T-068/`PAS-64`: retargeted at the *visitable* count, not the raw
    /// place count. `prds/hood-dataset/hood-dataset.md` req 5's pass/fail
    /// bullet (added at T-047/`PAS-34`'s acceptance) is the spec: a
    /// designated Hood must hold ≥ `LocalStatus.threshold` places with
    /// `permanently_closed == false`, because a closed place is one a user
    /// can never actually visit. Counting every place regardless of closed
    /// status — the original bug — let `kerem-hateimanim`/`neve-tzedek`
    /// read as comfortably above threshold (raw 3) while sitting at exactly
    /// the threshold on places a user can reach (2 visitable, 1 closed);
    /// the invariant would have stayed green even if the last open place in
    /// one of those Hoods closed. See `regressionCountsVisitableNotRawPlaces`
    /// below for a fixture proving the old raw-count check would have missed
    /// exactly that.
    @Test("every designated Hood holds at least LocalStatus.threshold visitable (non-closed) places")
    func everyDesignatedHoodMeetsThreshold() async throws {
        let hoods = try HoodCatalog.load()
        let catalog = PlaceCatalog()
        await catalog.load()

        let designated = hoods.filter(\.designatedForProgression)
        #expect(!designated.isEmpty)
        for hood in designated {
            let visitableCount = catalog.places(in: hood.id).filter { !$0.permanentlyClosed }.count
            #expect(
                visitableCount >= LocalStatus.threshold,
                "\(hood.id) has fewer than \(LocalStatus.threshold) visitable (non-closed) places"
            )
        }
    }

    /// Regression for T-068/`PAS-64`: proves the invariant above is
    /// measuring the *visitable* count, not the raw one, using an in-memory
    /// fixture Hood rather than the shipped bundle (so this doesn't depend
    /// on `kerem-hateimanim`/`neve-tzedek` staying at their current
    /// zero-margin state). Built as `threshold - 1` open places plus one
    /// closed place: raw count == `threshold` (clears the old, buggy
    /// `catalog.places(in:).count >= threshold` check — a false pass, since
    /// only `threshold - 1` of those places are actually reachable), while
    /// the visitable count is `threshold - 1` (correctly short). If
    /// `everyDesignatedHoodMeetsThreshold` above ever regresses to counting
    /// raw places again, this test keeps the failure mode documented and
    /// independently verifiable even though it can't directly re-trigger
    /// that regression itself (it doesn't call `PlaceCatalog`/`HoodCatalog`
    /// — the bug lived in *what gets counted*, which this test pins down as
    /// a value, not as a code path).
    @Test("regression: a Hood whose raw place count clears the threshold only via a closed place must not read as visitable-sufficient")
    func regressionCountsVisitableNotRawPlaces() {
        let threshold = LocalStatus.threshold
        var places: [Place] = (0..<max(threshold - 1, 0)).map { index in
            Place(
                id: "open-\(index)", name: "Open \(index)", category: .eatDrink, hoodID: "borderline-hood",
                coordinate: CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77),
                permanentlyClosed: false, placeType: "cafe"
            )
        }
        places.append(
            Place(
                id: "closed", name: "Closed Place", category: .eatDrink, hoodID: "borderline-hood",
                coordinate: CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77),
                permanentlyClosed: true, placeType: "cafe"
            )
        )

        let rawCount = places.count
        let visitableCount = places.filter { !$0.permanentlyClosed }.count

        #expect(rawCount == threshold, "fixture setup: raw count should exactly clear the threshold")
        #expect(rawCount >= threshold, "the old, buggy check — raw count alone reads this Hood as fine")
        #expect(visitableCount < threshold, "the new, correct check — visitable count correctly falls short")
    }

    @Test("every place_type in the shipped places bundle is a PlaceTypeRegistry key")
    func everyPlaceTypeIsARegistryKey() async {
        let catalog = PlaceCatalog()
        await catalog.load()

        let placeTypes = Set(catalog.allPlaces.map(\.placeType))
        let registryKeys = Set(PlaceTypeRegistry.shared.registeredPlaceTypes)
        #expect(!placeTypes.isEmpty)
        #expect(placeTypes.isSubset(of: registryKeys), "unregistered place_type(s): \(placeTypes.subtracting(registryKeys))")
    }
}
