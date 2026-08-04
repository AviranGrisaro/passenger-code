import Testing
@testable import Passenger

/// TRD §9 row 3(a)/(d): four assertions, two on each side of each bound —
/// the 1.5× multiplier and the +900s ceiling are independently exercised,
/// not just the `min` of the two as a black box.
@Suite("RouteBounds")
struct RouteBoundsTests {
    @Test("constants match the TRD exactly (§9 row 3d)")
    func constantsMatchTRD() {
        #expect(RouteBounds.detourTimeMultiplier == 1.5)
        #expect(RouteBounds.detourTimeCeiling == 900)
    }

    @Test("the 1.5x multiplier binds on a short fast route, just inside and just outside it")
    func multiplierBinds() {
        // fast = 1200s -> 1.5x ceiling is 1800s, +900s ceiling is 2100s. The
        // multiplier is the tighter bound here, so it's the one under test.
        #expect(RouteBounds.accepts(scenic: 1799, fast: 1200))
        #expect(!RouteBounds.accepts(scenic: 1801, fast: 1200))
    }

    @Test("the +15min ceiling binds on a long fast route, just inside and just outside it")
    func ceilingBinds() {
        // fast = 3600s -> 1.5x is 5400s, +900s ceiling is 4500s. The ceiling
        // is the tighter bound here.
        #expect(RouteBounds.accepts(scenic: 4499, fast: 3600))
        #expect(!RouteBounds.accepts(scenic: 4501, fast: 3600))
    }

    @Test("accepts is a min of the two bounds, not two independent passes")
    func acceptsIsAMin() {
        // A scenic route that fails only the multiplier must be rejected
        // even though it would pass the ceiling alone, and vice versa.
        #expect(!RouteBounds.accepts(scenic: 1801, fast: 1200))  // fails multiplier (1800), passes ceiling (2100)
        #expect(!RouteBounds.accepts(scenic: 4501, fast: 3600))  // fails ceiling (4500), passes multiplier (5400)
    }
}
