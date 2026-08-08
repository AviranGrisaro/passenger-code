/// The closed depiction vocabulary behind the open `place_type` string
/// (passport TRD §3.3, D3, amended v3 §9 row 3(f)/(g)). Every key
/// `PlaceTypeRegistry` ships resolves to one of the six real cases (C2's
/// totality test) or `.generic` — the one case no registry entry points at,
/// reached only when a `place_type` string arrives that this build's bundled
/// registry has never heard of (§3.4).
///
/// **Each case depicts what the place actually is, not an abstract shape
/// bijected to it.** `product` rejected the original `cafe→circle,
/// restaurant→triangle, bar→diamond` mapping at T-037 acceptance
/// (`passenger-brain 1d1167f`, F1) — a bijection is not a match, and nothing
/// about a circle says "café." `StickerShapeDepictionGateTests` is the
/// build-time gate this comment describes: it fails the build if any case
/// name or `spokenName` is a geometry word, so this class of regression
/// cannot ship silently again.
///
/// `Places/` still knows no SwiftUI (TRD §2.3) — `symbolName` is a `String`,
/// exactly as `PlaceCategory.symbolName` already is.
enum StickerShape: String, Sendable, CaseIterable {
    /// cafe — a cup and saucer.
    case cup
    /// restaurant — a fork and knife.
    case cutlery
    /// bar — a wine glass.
    case glass
    /// market — a shopping basket.
    case basket
    /// museum — a framed picture, the exhibits glyph Aviran picked from
    /// rendered images (round 2) after the prior pick, comedy/tragedy masks
    /// (`theatermasks.fill`), read as "theater" rather than "museum" in
    /// `ios-developer`'s blind read — itself a replacement for the original
    /// columned-building front (`building.columns.fill`, read as "bank" or
    /// "courthouse" in `qa`'s blind read, passport TRD §9 row 3(g),
    /// `passport.md` req 3's tightened pass condition).
    case artframe
    /// landmark — binoculars, the sightseeing glyph.
    case binoculars
    case generic

    /// One SF Symbol per case (TRD §4.4), each a real depiction of the place
    /// type it stands for. `.generic`'s symbol is not registered to any
    /// `place_type` — nothing in `PlaceTypeRegistry` maps to it — it exists
    /// solely as the fallback `PlaceTypeRegistry.shape(for:)` returns for an
    /// unregistered key.
    var symbolName: String {
        switch self {
        case .cup: "cup.and.saucer.fill"
        case .cutlery: "fork.knife"
        case .glass: "wineglass.fill"
        case .basket: "basket.fill"
        case .artframe: "photo.artframe"
        case .binoculars: "binoculars.fill"
        case .generic: "seal.fill"
        }
    }

    /// The one spoken word per depiction (TRD §4.7, D12, amended v3 §9 row
    /// 7(a)) — **never the raw `place_type`, and never a geometry word**.
    /// Mirrors `PlaceCategory.displayName`'s precedent ("the only place a
    /// user-facing category string exists"): this is the only place a
    /// user-facing sticker-depiction string exists, and it names what a
    /// sighted user sees — a cup, cutlery, a glass — never the server's
    /// category vocabulary and never an abstract shape word. "Dr. Shakshuka,
    /// cutlery sticker" passes VoiceOver's own pass condition; "Dr.
    /// Shakshuka, triangle sticker" is exactly what this vocabulary exists
    /// to rule out.
    var spokenName: String {
        switch self {
        case .cup: "cup"
        case .cutlery: "cutlery"
        case .glass: "glass"
        case .basket: "basket"
        case .artframe: "frame"
        case .binoculars: "binoculars"
        case .generic: "marker"
        }
    }
}
