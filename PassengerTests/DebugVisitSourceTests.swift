import Foundation
import Testing
@testable import Passenger

/// tourist-trap-flag TRD §8 D7, §11 C11.
@Suite("DebugVisitSource")
struct DebugVisitSourceTests {
    @Test("without the launch argument, the stream finishes with zero events — a real launch never carries this argument")
    func noArgumentEmitsNothing() async {
        let source = DebugVisitSource(arguments: ["Passenger"])
        var events: [VisitEvent] = []
        for await event in source.events { events.append(event) }
        #expect(events.isEmpty)
    }

    @Test("with -simulateLocalQAVisit <place-id>, emits exactly one .debug event for that place")
    func argumentEmitsOneDebugEvent() async {
        let fixedNow = Date(timeIntervalSince1970: 42)
        let source = DebugVisitSource(
            arguments: ["Passenger", "-simulateLocalQAVisit", "florentin-anna-loulou-bar"],
            now: { fixedNow }
        )
        var events: [VisitEvent] = []
        for await event in source.events { events.append(event) }

        #expect(events.count == 1)
        #expect(events.first?.placeID == "florentin-anna-loulou-bar")
        #expect(events.first?.trigger == .debug)
        #expect(events.first?.occurredAt == fixedNow)
    }

    @Test("the flag with no following value emits nothing rather than crashing")
    func flagWithNoValueEmitsNothing() async {
        let source = DebugVisitSource(arguments: ["Passenger", "-simulateLocalQAVisit"])
        var events: [VisitEvent] = []
        for await event in source.events { events.append(event) }
        #expect(events.isEmpty)
    }
}

/// tourist-trap-flag TRD §3.3, §8 D9.
@Suite("LocalQAInstallIdentity")
struct LocalQAInstallIdentityTests {
    @Test("generate() produces a fresh, distinct id each call")
    func generateProducesDistinctIDs() {
        let a = LocalQAInstallIdentity.generate()
        let b = LocalQAInstallIdentity.generate()
        #expect(a != b)
    }
}
