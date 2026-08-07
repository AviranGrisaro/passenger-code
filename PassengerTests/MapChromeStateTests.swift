import Testing
@testable import Passenger

/// `MapChromeState` is T-032's type (`time-slider/TRD.md` §4.1), reproduced
/// verbatim here (places-been-saved TRD §2.2, §4.5) because this task
/// created the file first in the shared working tree. Per TRD §11 C6, "the
/// test is T-036's regardless of who wrote the type" — this covers the
/// exclusivity rule both tasks depend on: presenting a surface replaces
/// whatever was open, and presenting the already-open surface closes it.
@Suite("MapChromeState")
@MainActor
struct MapChromeStateTests {
    @Test("starts with nothing presented")
    func startsClosed() {
        let chrome = MapChromeState()
        #expect(chrome.presented == nil)
        #expect(!chrome.isPresenting)
    }

    @Test("toggle presents a surface that wasn't open")
    func togglePresents() {
        let chrome = MapChromeState()
        chrome.toggle(.places)
        #expect(chrome.presented == .places)
        #expect(chrome.isPresenting)
    }

    @Test("toggle on the already-presented surface closes it — swaps, never stacks")
    func toggleOnOpenSurfaceCloses() {
        let chrome = MapChromeState()
        chrome.toggle(.places)
        chrome.toggle(.places)
        #expect(chrome.presented == nil)
        #expect(!chrome.isPresenting)
    }

    @Test("toggle to a different surface replaces the open one, never stacks")
    func toggleToDifferentSurfaceReplaces() {
        let chrome = MapChromeState()
        chrome.toggle(.places)
        chrome.toggle(.search)
        #expect(chrome.presented == .search)
    }

    @Test("dismiss always clears, regardless of what was presented")
    func dismissClears() {
        let chrome = MapChromeState()
        chrome.toggle(.places)
        chrome.dismiss()
        #expect(chrome.presented == nil)
    }

    @Test("dismiss on an already-closed state is a no-op, not a crash")
    func dismissWhenAlreadyClosedIsNoOp() {
        let chrome = MapChromeState()
        chrome.dismiss()
        #expect(chrome.presented == nil)
    }
}
