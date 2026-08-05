import Foundation
import Testing
import UIKit
@testable import Passenger

/// passport TRD §3.3, §11 C2 — the totality test: every key in the shipped
/// registry maps to a non-`.generic` `StickerShape` whose `symbolName`
/// resolves to a real SF Symbol. This is the build-time gate; `StickerShape`
/// being a closed enum alone is not, because the registry's key is a
/// `String` (§3.3).
@Suite("PlaceTypeRegistry")
struct PlaceTypeRegistryTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    // MARK: - C2's totality test, against the real shipped registry

    @Test("every key in the shipped place-type registry maps to a non-generic StickerShape")
    func everyShippedKeyResolvesToARealShape() {
        let registry = PlaceTypeRegistry.shared
        #expect(!registry.registeredPlaceTypes.isEmpty)
        for placeType in registry.registeredPlaceTypes {
            #expect(registry.shape(for: placeType) != .generic, "\(placeType) resolved to .generic")
        }
    }

    @Test("every shape a registered key resolves to has a real, renderable SF Symbol")
    func everyResolvedShapeHasARealSymbol() {
        let registry = PlaceTypeRegistry.shared
        for placeType in registry.registeredPlaceTypes {
            let shape = registry.shape(for: placeType)
            #expect(UIImage(systemName: shape.symbolName) != nil, "\(shape) symbolName invalid: \(shape.symbolName)")
        }
    }

    @Test("the shipped registry covers exactly the six place_type values the places bundle ships")
    func shippedRegistryCoversTheSixShippedPlaceTypes() {
        let registry = PlaceTypeRegistry.shared
        #expect(Set(registry.registeredPlaceTypes) == ["bar", "cafe", "landmark", "market", "museum", "restaurant"])
    }

    // MARK: - Fallback behaviour (defence in depth, §3.3)

    @Test("an unregistered place_type resolves to .generic, never a crash")
    func unregisteredKeyIsGeneric() {
        #expect(PlaceTypeRegistry.shared.shape(for: "not-a-real-place-type") == .generic)
    }

    @Test("a missing registry resource yields an empty registry, never a crash")
    func missingResourceIsEmpty() {
        let registry = PlaceTypeRegistry(resourceName: "does-not-exist", bundle: Self.testBundle)
        #expect(registry.registeredPlaceTypes.isEmpty)
        #expect(registry.shape(for: "cafe") == .generic)
    }

    // MARK: - Test fixture behaviour (isolated from the shipped file)

    @Test("a fixture registry resolves its own keys and degrades an unknown one")
    func fixtureRegistryResolvesItsOwnKeys() {
        let registry = PlaceTypeRegistry(resourceName: "place-types-test-fixture", bundle: Self.testBundle)
        #expect(registry.shape(for: "cafe") == .cup)
        #expect(registry.shape(for: "bar") == .glass)
        #expect(registry.shape(for: "does-not-exist") == .generic)
    }
}
