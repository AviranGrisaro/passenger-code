import Foundation

/// **T-032's type, reproduced verbatim from `time-slider/TRD.md` §4.1.**
/// T-032's C1 owns this file; places-been-saved (T-036) is a consumer only —
/// it adds no case, no conformance and no method (places-been-saved TRD
/// §2.2). This copy was created by T-036 because it landed first in the
/// shared working tree; T-032's own C1 will find the file already correct
/// and add nothing to it. If T-032's real §4.1 ever changes before this file
/// is touched again, this comment is the tripwire: diff the two before
/// trusting either.
///
/// Four cases, one view per surface. The four-member set is not invented
/// here — `ux-flows.md` §2.1 locks it, and T-032's own commentary says the
/// full set ships up front specifically to stop T-036/T-037/T-038 each
/// inventing a private boolean. `.search` and `.profile` have no view in
/// this task's diff — a case with no view ships nothing.
enum NavSurface: String, CaseIterable, Sendable, Identifiable {
    case search, heat, places, profile
    var id: String { rawValue }
}

@MainActor
@Observable
final class MapChromeState {
    private(set) var presented: NavSurface?
    var isPresenting: Bool { presented != nil }

    /// Exclusivity (`ux-flows.md` §2.1): presenting a surface replaces
    /// whatever was open — it never stacks. Presenting the already-open
    /// surface closes it.
    func toggle(_ surface: NavSurface) {
        presented = (presented == surface) ? nil : surface
    }

    func dismiss() {
        presented = nil
    }
}
