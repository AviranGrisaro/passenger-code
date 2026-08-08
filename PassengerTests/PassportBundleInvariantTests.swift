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
    /// Fixture-bundle injection seam, same pattern as `PlaceCatalogTests`/
    /// `PlaceTouristTrapDecodeTests` — a private token class defined in this
    /// test file resolves `Bundle(for:)` to the `PassengerTests` bundle,
    /// which carries the committed `Fixtures/*.json` files, not `Bundle.main`.
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

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
    ///
    /// The per-Hood check itself lives in `hoodMeetsVisitableThreshold`
    /// below (T-089/`PAS-87`) so the regression test can call the exact same
    /// logic against an injected fixture, instead of re-deriving its own
    /// copy of the rule that would stay green through a revert of this one.
    @Test("every designated Hood holds at least LocalStatus.threshold visitable (non-closed) places")
    func everyDesignatedHoodMeetsThreshold() async throws {
        let hoods = try HoodCatalog.load()
        let catalog = PlaceCatalog()
        await catalog.load()

        let designated = hoods.filter(\.designatedForProgression)
        #expect(!designated.isEmpty)
        for hood in designated {
            #expect(
                Self.hoodMeetsVisitableThreshold(hood, catalog: catalog, threshold: LocalStatus.threshold),
                "\(hood.id) has fewer than \(LocalStatus.threshold) visitable (non-closed) places"
            )
        }
    }

    /// The invariant's actual rule, extracted to a standalone, injectable
    /// function (T-089/`PAS-87`) — takes a `Hood` and an already-loaded
    /// `PlaceCatalog` rather than reaching for `HoodCatalog.load()`/
    /// `PlaceCatalog()` itself, so it is callable against either the live
    /// shipped bundle (`everyDesignatedHoodMeetsThreshold` above) or an
    /// injected test fixture (`regressionCountsVisitableNotRawPlaces`
    /// below) with zero duplicated logic. Pass/fail behavior is unchanged
    /// from before the extraction — same expression, now named and shared.
    private static func hoodMeetsVisitableThreshold(_ hood: Hood, catalog: PlaceCatalog, threshold: Int) -> Bool {
        catalog.places(in: hood.id).filter { !$0.permanentlyClosed }.count >= threshold
    }

    /// Regression for T-068/`PAS-64`, hardened at T-089/`PAS-87` to actually
    /// guard the fix rather than just document it. Loads a fixture Hood
    /// (`designatedForProgression: true`) and a fixture `PlaceCatalog`
    /// through the same `seedResourceName`/`hoodResourceName`/`bundle`
    /// injection seam `PlaceCatalogTests`/`PlaceTouristTrapDecodeTests`/
    /// `PlacePlaceTypeDecodeTests`/`PlaceKeywordsDecodeTests`/`EventStoreTests`
    /// already use — the previously recorded "`PlaceCatalog` isn't
    /// fixture-injectable" justification was wrong; the seam was always
    /// there. This doesn't depend on `kerem-hateimanim`/`neve-tzedek`
    /// staying at their current zero-margin state.
    ///
    /// The fixture is `threshold - 1` open places plus one closed place: raw
    /// count == `threshold` (would clear the old, buggy
    /// `catalog.places(in:).count >= threshold` check — a false pass, since
    /// only `threshold - 1` of those places are actually reachable), while
    /// the visitable count is `threshold - 1` (correctly short). Calling
    /// `hoodMeetsVisitableThreshold` — the exact function
    /// `everyDesignatedHoodMeetsThreshold` above calls — against this
    /// fixture means a revert of that function back to raw counting flips
    /// this test's result from fail (correct) to pass (wrong), so it now
    /// actually re-triggers the regression it documents rather than only
    /// describing it. Verified by hand: temporarily reverting
    /// `hoodMeetsVisitableThreshold` to `catalog.places(in: hood.id).count
    /// >= threshold` makes this test fail, as expected; the fix was then
    /// restored.
    @Test("regression: a Hood whose raw place count clears the threshold only via a closed place must not read as visitable-sufficient")
    func regressionCountsVisitableNotRawPlaces() async throws {
        // The fixture below is built for LocalStatus.threshold == 2 (one
        // open place + one closed place). If the threshold ever changes,
        // this guard fails loudly instead of the fixture silently no longer
        // exercising the case it's meant to.
        #expect(LocalStatus.threshold == 2, "fixture assumes threshold == 2 — update the fixture and this test if it changes")

        let hoods = try HoodCatalog.load(resourceName: "hoods-designated-threshold-fixture", bundle: Self.testBundle)
        let hood = try #require(hoods.first { $0.id == "borderline-hood" })
        #expect(hood.designatedForProgression)

        let catalog = PlaceCatalog(
            seedResourceName: "places-designated-threshold-fixture",
            hoodResourceName: "hoods-designated-threshold-fixture",
            bundle: Self.testBundle
        )
        await catalog.load()

        let rawCount = catalog.places(in: hood.id).count
        let visitableCount = catalog.places(in: hood.id).filter { !$0.permanentlyClosed }.count
        #expect(rawCount == LocalStatus.threshold, "fixture setup: raw count should exactly clear the threshold")
        #expect(visitableCount == LocalStatus.threshold - 1, "fixture setup: visitable count should fall exactly one short")

        #expect(
            Self.hoodMeetsVisitableThreshold(hood, catalog: catalog, threshold: LocalStatus.threshold) == false,
            "a Hood with \(LocalStatus.threshold - 1) open + 1 closed place must not read as visitable-sufficient, even though its raw count clears the threshold"
        )
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
