import CoreLocation
import Testing
@testable import Passenger

/// TRD §4.10 — the copy table, and its case→string mapping (§9 row 4a: all
/// 6 `ScenicUnavailable` cases). Pulled out of the view so it's testable
/// without a host, same as `FlagCopyTests`.
@Suite("RouteControlsCopy")
struct RouteControlsCopyTests {
    @Test("all 6 ScenicUnavailable cases produce the exact TRD §4.10 copy")
    func disabledTextMatchesTRDTable() {
        #expect(RouteControlsCopy.disabledText(for: .originAndDestinationShareAHood) == "You're already in this neighborhood.")
        #expect(RouteControlsCopy.disabledText(for: .walkTooShort) == "Too short for a scenic detour.")
        #expect(RouteControlsCopy.disabledText(for: .noQualifyingHood) == "No scenic alternative for this walk.")
        #expect(RouteControlsCopy.disabledText(for: .notDistinct) == "No scenic alternative for this walk.")
        #expect(RouteControlsCopy.disabledText(for: .detourTooLong) == "No scenic alternative for this walk.")
        #expect(RouteControlsCopy.disabledText(for: .routingFailed) == "No scenic alternative for this walk.")
    }

    @Test("the last four cases collapse to the same copy but stay distinguishable in code")
    func collapsedCasesAreStillDistinctEnumValues() {
        let collapsed: Set<ScenicUnavailable> = [.noQualifyingHood, .notDistinct, .detourTooLong, .routingFailed]
        #expect(collapsed.count == 4)
        #expect(collapsed.allSatisfy { RouteControlsCopy.disabledText(for: $0) == "No scenic alternative for this walk." })
    }

    @Test("durationText rounds to whole minutes, minimum 1")
    func durationTextRoundsToMinutes() {
        #expect(RouteControlsCopy.durationText(60) == "1 min")
        #expect(RouteControlsCopy.durationText(90) == "2 min")  // rounds up
        #expect(RouteControlsCopy.durationText(600) == "10 min")
        #expect(RouteControlsCopy.durationText(10) == "1 min")  // never rounds to 0
    }

    @Test("distanceText uses metres under 1km, kilometres at or above it")
    func distanceTextSwitchesUnitAtOneKilometre() {
        #expect(RouteControlsCopy.distanceText(500) == "500 m")
        #expect(RouteControlsCopy.distanceText(999) == "999 m")
        #expect(RouteControlsCopy.distanceText(1000) == "1.0 km")
        #expect(RouteControlsCopy.distanceText(1600) == "1.6 km")
    }

    @Test("subtitle includes the via-Hood name for a scenic plan, and omits it for fast")
    func subtitleIncludesViaHoodNameOnlyWhenPresent() {
        let fast = RoutePlan(kind: .fast, coordinates: [], distance: 500, travelTime: 600, viaHoodName: nil)
        let scenic = RoutePlan(kind: .scenic, coordinates: [], distance: 800, travelTime: 900, viaHoodName: "Florentin")
        #expect(!RouteControlsCopy.subtitle(for: fast).contains("via"))
        #expect(RouteControlsCopy.subtitle(for: scenic).contains("via Florentin"))
    }
}
