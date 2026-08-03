import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// search-quick-filters TRD §9 row 5(c), §11 C14 — the "structural guard"
/// half of C14 that `ios-code-reviewer` flagged as specified but not shipped
/// (2026-08-03, APPROVE WITH MINORS, item 8): a grep-backed assertion that
/// exactly two `.sheet(isPresented:` call sites exist app-wide, so PRD req 5
/// bullet 3's depth ceiling is enforced by there being nowhere else for a
/// third presentation site to hide (§4.9's own reasoning), not merely true
/// today by inspection. Closed by `qa` at the T-038/PAS-29 QA pass rather
/// than left as a property someone re-derives by eye next time.
///
/// Same construction as `PassportAbsenceGateTests` (T-037): reads the actual
/// Swift source via `#filePath`, resolved against the checkout on the build
/// machine, and asserts on content directly rather than trusting that the
/// module boundary holds by convention. Unlike that file, this guard is
/// **app-wide**, not scoped to one feature's file list — TRD row 5(c) is an
/// app-wide invariant ("exactly 2 call sites in view code" across
/// `Passenger`, not just `Search/`/`SearchSheet/`), so a directory walk is
/// the right shape here, not a fixed list.
@Suite("Search — structural guards (TRD §9 row 5c, §11 C14)")
struct SearchStructuralGuardTests {
    private struct SourceHit: CustomStringConvertible {
        let file: String
        let line: Int
        let text: String
        var description: String { "\(file):\(line): \(text)" }
    }

    /// Walks `Passenger/` (the app target only — not `PassengerTests`/
    /// `PassengerUITests`, which legitimately reference `.sheet(isPresented:`
    /// in their own assertions) and returns every line containing the
    /// substring, tagged with file and 1-based line number.
    private static func findAppSourceLines(containing needle: String) throws -> [SourceHit] {
        let thisFile = URL(fileURLWithPath: #filePath)
        // PassengerTests/SearchStructuralGuardTests.swift -> repo root.
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        let appRoot = repoRoot.appendingPathComponent("Passenger")

        guard let enumerator = FileManager.default.enumerator(
            at: appRoot, includingPropertiesForKeys: nil
        ) else {
            throw TestSetupError.enumeratorFailed
        }

        var hits: [SourceHit] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            let fileName = url.lastPathComponent
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                guard line.contains(needle) else { continue }
                hits.append(SourceHit(file: fileName, line: index + 1, text: String(line)))
            }
        }
        return hits
    }

    private enum TestSetupError: Error { case enumeratorFailed }

    /// Doc-comment mentions (`DetailRouter.swift`'s own explanatory
    /// comments naming "site A"/"site B") contain the literal substring
    /// `.sheet(isPresented:` too — a naive grep over-counts by exactly those
    /// two lines. The TRD's own pass condition (§9 row 5c) excludes them
    /// ("doc-comment mentions in `DetailRouter` don't count and don't match
    /// this pattern") — implemented here as "not a `///` line," which is
    /// what actually distinguishes them, rather than assumed true of the
    /// raw grep.
    private static func isDocComment(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("///")
    }

    @Test("§9 row 5(c): exactly two real `.sheet(isPresented:` call sites exist app-wide")
    func exactlyTwoSheetPresentationSites() throws {
        let allHits = try Self.findAppSourceLines(containing: ".sheet(isPresented:")
        let realCallSites = allHits.filter { !Self.isDocComment($0.text) }
        let docCommentMentions = allHits.filter { Self.isDocComment($0.text) }

        #expect(
            realCallSites.count == 2,
            "expected exactly 2 real `.sheet(isPresented:` call sites, found \(realCallSites.count): \(realCallSites)"
        )
        // Named explicitly so a future reader sees the exclusion was a
        // deliberate content check, not a missed count.
        #expect(
            !docCommentMentions.isEmpty,
            "expected DetailRouter's own doc-comment mentions of the pattern to still exist and be excluded by content, not by file name"
        )
    }

    // MARK: - §9 row 5(c) second half — the depth ceiling, driven through
    // this task's own search-selection flow rather than re-testing the
    // generic invariant `DetailRouterTests.depthNeverExceedsTwo` already
    // covers (that test predates this task and is not re-derived here).

    private static func makeHood(id: String) -> Hood {
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        return Hood(
            id: id, name: id, ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        )
    }

    private static func makePlace(id: String, hoodID: String) -> Place {
        Place(
            id: id, name: id, category: .eatDrink, hoodID: hoodID,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            permanentlyClosed: false, placeType: "cafe", isTouristTrap: nil, keywords: []
        )
    }

    @Test("selecting a Hood result then a place result from search never exceeds depth 2")
    @MainActor
    func searchResultSelectionNeverExceedsDepthTwo() {
        let router = DetailRouter()

        // Hood result tap (TRD §4.9): clear() + openHood — search's own
        // "goes where the map would have gone" path for a Hood.
        router.openHood(Self.makeHood(id: "florentin"))
        #expect((router.placeDepth ?? 0) <= 2)

        // Place result tap from within that Hood's sheet — the depth-2
        // destination search can also reach.
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))
        #expect((router.placeDepth ?? 0) <= 2)

        // A second place result tap while depth 2 is already presented
        // (swap, not stack) — the case §4.9's "no new `.sheet` site" claim
        // depends on.
        router.openPlace(Self.makePlace(id: "cafe-2", hoodID: "florentin"))
        #expect((router.placeDepth ?? 0) <= 2)
    }
}
