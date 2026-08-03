import Foundation
import Testing
@testable import Passenger

/// passport TRD §9 rows 1, 6, 8; §11 C13 — the "this must not exist" gates.
/// Reads the actual Swift source of every file this feature owns (via
/// `#filePath`, resolved against the checkout on the build machine — the
/// same machine `xcodebuild test` runs on, not a bundled resource) and
/// asserts on their content directly, rather than trusting that the module
/// boundaries in TRD §2.3 hold by convention alone. Per §11: "Failing any of
/// these fails the build step, not `qa`."
///
/// The file list below is TRD §2.1's own inventory for this feature. A file
/// added later to `Passport/` (or `StickerShape.swift`/
/// `PlaceTypeRegistry.swift`/`ProfileButton.swift`) needs adding here too —
/// this is a fixed list, not a directory scan, so a forgotten addition fails
/// loud (a missing file throws) rather than silently widening the feature's
/// boundary unchecked.
@Suite("Passport absence gates")
struct PassportAbsenceGateTests {
    private static func featureFiles() throws -> [String] {
        let thisFile = URL(fileURLWithPath: #filePath)
        // PassengerTests/PassportAbsenceGateTests.swift -> repo root (two
        // levels up: drop the filename, then the PassengerTests directory).
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        let relativePaths = [
            "Passenger/Passport/PassportComposition.swift",
            "Passenger/Passport/LocalStatus.swift",
            "Passenger/Passport/PassportSurface.swift",
            "Passenger/Passport/PassportAlbum.swift",
            "Passenger/Passport/PassportStickerView.swift",
            "Passenger/Passport/PassportProgressList.swift",
            "Passenger/Passport/PassportLabels.swift",
            "Passenger/Places/StickerShape.swift",
            "Passenger/Places/PlaceTypeRegistry.swift",
            "Passenger/Map/ProfileButton.swift",
        ]
        return try relativePaths.map { relativePath in
            let url = repoRoot.appendingPathComponent(relativePath)
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    // MARK: - Row 1(a): no social/account/sharing symbol anywhere in the feature

    @Test("row 1(a): zero hits for any of the nine social/account/sharing symbols")
    func noSocialOrAccountSymbols() throws {
        let banned = [
            "ShareLink", "UIActivityViewController", "AuthenticationServices",
            "ASAuthorization", "SignInWith", "URLSession", "PhotosUI", "UIImagePickerController",
        ]
        for source in try Self.featureFiles() {
            for symbol in banned {
                #expect(!source.contains(symbol), "found banned symbol \(symbol)")
            }
        }
    }

    // MARK: - Row 1(b): every Image(...) is a literal system symbol, never user imagery

    @Test("row 1(b): every Image( call site in the feature uses a literal systemName:")
    func everyImageIsASystemSymbol() throws {
        for source in try Self.featureFiles() {
            for line in source.split(separator: "\n") {
                guard line.contains("Image(") else { continue }
                #expect(line.contains("Image(systemName:"), "non-system Image( call: \(line)")
            }
        }
    }

    // MARK: - Row 6: no interruption/celebration presenter, no count-keyed animation

    @Test("row 6: zero interruption/celebration presenters")
    func noInterruptionPresenters() throws {
        let banned = [".alert(", ".fullScreenCover(", ".sheet(", ".confirmationDialog("]
        for source in try Self.featureFiles() {
            for symbol in banned {
                #expect(!source.contains(symbol), "found banned presenter \(symbol)")
            }
        }
    }

    // MARK: - Row 8: no location or network symbol, no authorization read

    @Test("row 8: zero CoreLocation/authorization/network symbols")
    func noLocationOrNetworkSymbols() throws {
        let banned = [
            "CoreLocation", "CLLocationManager", "CLAuthorizationStatus",
            "authorizationStatus", "URLSession", "URLRequest",
        ]
        for source in try Self.featureFiles() {
            for symbol in banned {
                #expect(!source.contains(symbol), "found banned symbol \(symbol)")
            }
        }
    }

    // MARK: - §9 rows 2(e)/7(c): no camera/hour read, and the one real
    // interactive element sized to the Fitts's-Law minimum

    @Test("§9 row 2(e): zero reads or writes of camera/selectedHour — the structural proxy for row 2(d)'s byte-identical check")
    func noCameraOrHourAccess() throws {
        let banned = ["camera", "selectedHour"]
        for source in try Self.featureFiles() {
            for symbol in banned {
                #expect(!source.contains(symbol), "found banned symbol \(symbol)")
            }
        }
    }

    @Test("§9 row 7(c): PassportSurface's close button is the ≥44×44pt Fitts's-Law minimum")
    func closeButtonMeetsMinimumTarget() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Passenger/Passport/PassportSurface.swift"),
            encoding: .utf8
        )
        #expect(source.contains(".frame(width: 44, height: 44)"))
    }
}
