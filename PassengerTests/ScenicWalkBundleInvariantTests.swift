import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// scenic-walk TRD §9 row 8(a)/(b), step C9 — the Build-Phase-1 fixture's
/// shipped-bundle invariants (req 8). Reads the real compiled bundle
/// (`Bundle.main`, via `HoodCatalog.load()`), not a fixture, same discipline
/// `PassportBundleInvariantTests` already holds: this is about what
/// actually ships, not what the source JSON says before generation.
///
/// The fixture itself — `montefiore`/`shapira`/`old-north` flagged
/// `isTouristTrap: false` alongside the pre-existing `ramat-aviv` — was
/// authored by `data-engineer` at step A1 (`passenger-brain df88b91`,
/// `passenger-code 3435d85`), confirmed landed before writing this file.
/// Row 8(c)'s generator-determinism re-run (byte-identical SQL/JSON on a
/// scratch regeneration) is A1's own verification, already recorded in that
/// commit — not repeated here.
@Suite("Scenic Walk bundle invariants (req 8)")
@MainActor
struct ScenicWalkBundleInvariantTests {
    @Test("the shipped bundle carries exactly 24 Hoods and at least 4 false-flagged, including the 3 authored for this fixture")
    func falseFlagCountAndTotal() throws {
        let hoods = try HoodCatalog.load()
        #expect(hoods.count == 24)

        let falseFlagged = hoods.filter { $0.isTouristTrap == false }
        #expect(falseFlagged.count >= 4)

        let falseFlaggedIDs = Set(falseFlagged.map(\.id))
        #expect(["old-north", "montefiore", "shapira", "ramat-aviv"].allSatisfy { falseFlaggedIDs.contains($0) })
    }

    @Test("every pair of false-flagged Hoods is mutually non-adjacent: >50m vertex separation, >=800m centroid separation")
    func falseFlaggedHoodsAreMutuallyNonAdjacent() throws {
        let hoods = try HoodCatalog.load()
        let falseFlagged = hoods.filter { $0.isTouristTrap == false }
        let pairs = Self.pairs(of: falseFlagged)
        // The count assertion first (per the standing §9 rule): a suite
        // that only ever iterates zero pairs would pass vacuously.
        #expect(pairs.count >= 6)

        for (a, b) in pairs {
            let minVertexDistance = Self.minimumVertexSeparation(a, b)
            #expect(minVertexDistance > 50, "\(a.id) <-> \(b.id) minimum vertex separation was \(minVertexDistance)m")

            let centroidDistance = Self.distance(a.centroid, b.centroid)
            #expect(centroidDistance >= 800, "\(a.id) <-> \(b.id) centroid separation was \(centroidDistance)m")
        }
    }

    private static func pairs(of hoods: [Hood]) -> [(Hood, Hood)] {
        var result: [(Hood, Hood)] = []
        guard hoods.count >= 2 else { return result }
        for i in 0..<(hoods.count - 1) {
            for j in (i + 1)..<hoods.count {
                result.append((hoods[i], hoods[j]))
            }
        }
        return result
    }

    /// The minimum distance between any vertex of `a`'s ring and any vertex
    /// of `b`'s ring — today's *adjacent* Hoods share vertices exactly, at
    /// 0m (TRD §3.4 condition 2's own definition), so this is the same
    /// falsifiable adjacency test the fixture's authoring note computed.
    private static func minimumVertexSeparation(_ a: Hood, _ b: Hood) -> CLLocationDistance {
        var minDistance = Double.infinity
        for pointA in a.ring {
            for pointB in b.ring {
                minDistance = min(minDistance, distance(pointA.coordinate, pointB.coordinate))
            }
        }
        return minDistance
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
