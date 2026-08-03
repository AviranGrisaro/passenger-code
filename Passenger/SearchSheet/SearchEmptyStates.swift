import SwiftUI

/// The two non-list states the result area can be in (TRD §9 row 6a/6b) —
/// neither is an error, and neither is a "suggestion row" dressed up as one.
enum SearchEmptyStates {
    /// An empty field with no chip active (PRD req 6) — nothing to show
    /// because nothing has been asked yet.
    static func emptyField() -> some View {
        SearchStateMessage(text: "Search for a place or a Hood")
    }

    /// A non-empty query with zero matches. The query text is echoed
    /// verbatim (TRD §9 row 6b) so the user can see exactly what didn't
    /// match; the field itself keeps focus, which is `SearchOverlay`'s job,
    /// not this view's.
    static func noMatch(query: String) -> some View {
        SearchStateMessage(text: "No results for \u{201C}\(query)\u{201D}")
    }
}

private struct SearchStateMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .padding(.top, 32)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
    }
}
