import SwiftUI

/// One result row (TRD §4.8, PRD req 4 bullet 7, req 8). `SearchSheet/` knows
/// no map and no router — this renders a `SearchResult`'s already-resolved
/// data and nothing else. **No tourist-trap line, ever**: the flag has one
/// home (T-035 req 6), and this view reads no such field.
struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .fixedSize(horizontal: false, vertical: true)
                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)  // Fitts's Law minimum (design-principles.md §2)
        .contentShape(Rectangle())
        // One accessibility element speaking the pinned VoiceOver string
        // (§9 row 8b) — not the two visible `Text` runs read separately.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result.voiceOverLabel)
    }

    /// `"Hood"` for a Hood row; `"Place · <category> · <hood>"` for a place
    /// row (PRD req 4 bullet 7, D9's two-word type vocabulary).
    private var secondaryLine: String {
        switch result.kind {
        case .hood:
            result.typeWord
        case .place(let place, _):
            "\(result.typeWord) · \(place.category.displayName) · \(result.hoodName ?? "")"
        }
    }
}
