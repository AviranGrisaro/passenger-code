import Foundation
import Testing
@testable import Passenger

@Suite("HoodCatalog")
struct HoodCatalogTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    @Test("loads a well-formed bundled fixture")
    func loadsWellFormedFixture() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-test-fixture", bundle: Self.testBundle)
        #expect(hoods.count == 2)
        #expect(hoods.map(\.id).sorted() == ["florentin", "kerem-hateimanim"])
        #expect(hoods.allSatisfy { $0.ring.count >= 3 })
    }

    @Test("throws rather than returning an empty catalog when the resource is missing")
    func missingResourceThrows() {
        #expect(throws: HoodCatalog.CatalogError.self) {
            _ = try HoodCatalog.load(resourceName: "does-not-exist", bundle: Self.testBundle)
        }
    }

    @Test("throws on a malformed entry (fewer than 3 points) rather than silently dropping it")
    func malformedEntryThrows() {
        #expect(throws: HoodCatalog.CatalogError.self) {
            _ = try HoodCatalog.load(resourceName: "hoods-malformed-fixture", bundle: Self.testBundle)
        }
    }

    // MARK: - hood-dataset TRD §4.3 decode assertions, pulled forward with C2
    // (architect's own bounded call, §8 D10: "a decode rule shipped without
    // the test that proves it is a rule nobody checked"). The non-overlap
    // tripwire over the *real* shipped bundle stays Phase 2 with the geometry
    // it exists to check (C4) — these three assertions do not need it.

    @Test("accepts schemaVersion 2, not just the version this bundle shipped at before")
    func acceptsSchemaVersion2() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-schema-v2-fixture", bundle: Self.testBundle)
        #expect(hoods.count == 2)
    }

    @Test("schemaVersion below 1 is rejected as malformed, not silently accepted")
    func schemaVersionBelowOneThrows() {
        #expect(throws: HoodCatalog.CatalogError.self) {
            _ = try HoodCatalog.load(resourceName: "hoods-schema-invalid-fixture", bundle: Self.testBundle)
        }
    }

    @Test("blank blurb (empty string or whitespace-only) normalizes to nil, never a placeholder")
    func blankBlurbNormalizesToNil() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-schema-v2-fixture", bundle: Self.testBundle)
        #expect(hoods.allSatisfy { $0.blurb == nil })
    }

    @Test("absent centroid falls back to the averaged-vertex centroid, so a stale bundle still loads correctly")
    func absentCentroidFallsBackToAveragedCentroid() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-schema-v2-fixture", bundle: Self.testBundle)
        let florentin = try #require(hoods.first { $0.id == "florentin" })

        // florentin's fixture polygon carries no "centroid" key. Expected
        // value is the plain average of its 4 open-ring vertices.
        let expectedLatitude = (32.050 + 32.050 + 32.058 + 32.058) / 4
        let expectedLongitude = (34.760 + 34.770 + 34.770 + 34.760) / 4
        #expect(abs(florentin.centroid.latitude - expectedLatitude) < 1e-9)
        #expect(abs(florentin.centroid.longitude - expectedLongitude) < 1e-9)
    }

    @Test("a bundle-provided centroid is used as-is, not recomputed from the vertices")
    func explicitCentroidIsUsedWhenPresent() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-schema-v2-fixture", bundle: Self.testBundle)
        let kerem = try #require(hoods.first { $0.id == "kerem-hateimanim" })

        // The fixture's explicit centroid (34.780, 32.056) deliberately
        // differs from the vertex average (34.779, 32.054) so this test can
        // tell "read from the bundle" apart from "recomputed anyway."
        #expect(abs(kerem.centroid.latitude - 32.056) < 1e-9)
        #expect(abs(kerem.centroid.longitude - 34.780) < 1e-9)
    }

    @Test("a closed ring (first == last) decodes with the duplicate closing point dropped")
    func closedRingDropsTrailingDuplicatePoint() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-schema-v2-fixture", bundle: Self.testBundle)
        let kerem = try #require(hoods.first { $0.id == "kerem-hateimanim" })

        // Fixture's polygon has 5 points (rectangle + repeated first point).
        // In-memory form is open per hood-dataset TRD §4.2.
        #expect(kerem.ring.count == 4)
    }

    // MARK: - hood-dataset TRD §3.1 D11: `aliases` (bundle schemaVersion 3)

    @Test("a Hood with a bundled alias decodes it into Hood.aliases")
    func decodesHoodAlias() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-with-aliases-fixture", bundle: Self.testBundle)
        let neveEliezer = try #require(hoods.first { $0.id == "neve-eliezer" })
        #expect(neveEliezer.aliases == ["Kfar Shalem"])
    }

    @Test("a Hood with an explicit empty aliases array decodes to []")
    func decodesEmptyAliasesArray() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-with-aliases-fixture", bundle: Self.testBundle)
        let kerem = try #require(hoods.first { $0.id == "kerem-hateimanim" })
        #expect(kerem.aliases == [])
    }

    @Test("a pre-schemaVersion-3 bundle with no aliases key at all still decodes, defaulting to []")
    func absentAliasesKeyDefaultsToEmptyArray() throws {
        let hoods = try HoodCatalog.load(resourceName: "hoods-schema-v2-fixture", bundle: Self.testBundle)
        #expect(hoods.allSatisfy { $0.aliases == [] })
    }
}
