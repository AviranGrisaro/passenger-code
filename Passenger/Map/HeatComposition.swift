import Foundation

/// One Hood paired with its band at a given hour (TRD §4.7).
struct HoodFill: Equatable, Sendable {
    let hood: Hood
    let band: HeatBand?
}

/// Pure hoods × hour → `[HoodFill]` (TRD §4.7). Takes a lookup closure, not
/// a `DensityStore` — testable with no store, no network, no simulator, and
/// this is what gives the repaint a single nameable completion point:
/// `MapScreen`'s body resolves fills **once per pass** through this
/// function and iterates the result, instead of calling
/// `densityStore.band(...)` inline per Hood.
enum HeatComposition {
    static func fills(hoods: [Hood], hour: Int, band: (String, Int) -> HeatBand?) -> [HoodFill] {
        hoods.map { hood in HoodFill(hood: hood, band: band(hood.id, hour)) }
    }
}
