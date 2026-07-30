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
}
