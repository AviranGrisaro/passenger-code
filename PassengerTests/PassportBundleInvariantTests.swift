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

    @Test("every designated Hood holds at least LocalStatus.threshold curated places")
    func everyDesignatedHoodMeetsThreshold() async throws {
        let hoods = try HoodCatalog.load()
        let catalog = PlaceCatalog()
        await catalog.load()

        let designated = hoods.filter(\.designatedForProgression)
        #expect(!designated.isEmpty)
        for hood in designated {
            #expect(
                catalog.places(in: hood.id).count >= LocalStatus.threshold,
                "\(hood.id) has fewer than \(LocalStatus.threshold) curated places"
            )
        }
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
