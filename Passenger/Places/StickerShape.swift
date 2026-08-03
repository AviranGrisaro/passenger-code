/// The closed shape vocabulary behind the open `place_type` string (passport
/// TRD §3.3, D3). Every key `PlaceTypeRegistry` ships resolves to one of the
/// six real cases (C2's totality test) or `.generic` — the one case no
/// registry entry points at, reached only when a `place_type` string arrives
/// that this build's bundled registry has never heard of (§3.4).
///
/// `Places/` still knows no SwiftUI (TRD §2.3) — `symbolName` is a `String`,
/// exactly as `PlaceCategory.symbolName` already is.
enum StickerShape: String, Sendable, CaseIterable {
    case circle, square, triangle, diamond, star, hexagon
    case generic

    /// One SF Symbol per case (TRD §4.4). `.generic`'s symbol is not
    /// registered to any `place_type` — nothing in `PlaceTypeRegistry` maps
    /// to it — it exists solely as the fallback `PlaceTypeRegistry.shape(for:)`
    /// returns for an unregistered key.
    var symbolName: String {
        switch self {
        case .circle: "circle.fill"
        case .square: "square.fill"
        case .triangle: "triangle.fill"
        case .diamond: "diamond.fill"
        case .star: "star.fill"
        case .hexagon: "hexagon.fill"
        case .generic: "seal.fill"
        }
    }

    /// The one spoken word per shape (TRD §4.7, D12) — **never the raw
    /// `place_type`**. Mirrors `PlaceCategory.displayName`'s precedent ("the
    /// only place a user-facing category string exists"): this is the only
    /// place a user-facing shape string exists, and it names what a sighted
    /// user sees — the shape — not the server's category vocabulary.
    var spokenName: String {
        switch self {
        case .circle: "circle"
        case .square: "square"
        case .triangle: "triangle"
        case .diamond: "diamond"
        case .star: "star"
        case .hexagon: "hexagon"
        case .generic: "shape"
        }
    }
}
