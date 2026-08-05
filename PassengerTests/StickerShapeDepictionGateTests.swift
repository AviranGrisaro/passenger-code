import Testing
@testable import Passenger

/// passport TRD §9 row 3(f), amended v3 (T-069/`PAS-65`), §11 C2 — the
/// zero-geometry-word build gate. `product` rejected the original
/// `cafe→circle, restaurant→triangle, bar→diamond` mapping at T-037
/// acceptance (`passenger-brain 1d1167f`, F1): a bijection between place
/// types and abstract geometry is not a depiction, and nothing anywhere
/// downstream had an objective check to fail it on. This suite is that
/// check — it fails the build step, not `qa` (per §11: "Failing any of these
/// fails the build step, not qa"), so this class of regression cannot ship
/// silently a second time.
///
/// **Positive control (§9 row 3(f), L-032):** asserted in every test before
/// the geometry-word search runs, so the search can never pass vacuously
/// over an empty or trivial case set — a `StickerShape` reduced to nothing
/// but `.generic` would make the search below trivially true for the wrong
/// reason.
@Suite("StickerShape depiction gate")
struct StickerShapeDepictionGateTests {
    /// The closed fail-list from TRD §9 row 3(f), verbatim.
    private static let bannedGeometryWords: Set<String> = [
        "circle", "square", "triangle", "diamond", "star", "hexagon",
        "pentagon", "octagon", "oval", "rectangle", "polygon", "dot", "blob", "shape",
    ]

    private static var nonGenericCases: [StickerShape] {
        StickerShape.allCases.filter { $0 != .generic }
    }

    // MARK: - Positive control

    @Test("positive control: the enum exposes at least six non-generic cases")
    func enumExposesAtLeastSixNonGenericCases() {
        #expect(Self.nonGenericCases.count >= 6)
    }

    @Test("positive control: the shipped registry carries at least six keys")
    func registryCarriesAtLeastSixKeys() {
        #expect(PlaceTypeRegistry.shared.registeredPlaceTypes.count >= 6)
    }

    // MARK: - Row 3(f): zero geometry words, case names

    @Test("zero whole-word geometry-word hits across every StickerShape case name")
    func noGeometryWordInAnyCaseName() {
        // Re-assert the positive control at the point of use — never trust a
        // prior test's ordering or a shared setup step to have run first.
        #expect(Self.nonGenericCases.count >= 6)

        for shape in StickerShape.allCases {
            let caseName = String(describing: shape).lowercased()
            #expect(
                !Self.bannedGeometryWords.contains(caseName),
                "case name '.\(caseName)' is a geometry word — depict the place type instead"
            )
        }
    }

    // MARK: - Row 3(f)/7(a): zero geometry words, spokenName

    @Test("zero whole-word geometry-word hits across every spokenName value")
    func noGeometryWordInAnySpokenName() {
        #expect(Self.nonGenericCases.count >= 6)

        for shape in StickerShape.allCases {
            let words = shape.spokenName
                .lowercased()
                .split { !$0.isLetter }
                .map(String.init)
            for word in words {
                #expect(
                    !Self.bannedGeometryWords.contains(word),
                    "spokenName '\(shape.spokenName)' (case .\(shape.rawValue)) contains geometry word '\(word)'"
                )
            }
        }
    }
}
