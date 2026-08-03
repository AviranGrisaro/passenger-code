import SwiftUI

/// One row of the Places list (TRD §4.4). Order top to bottom per the design
/// spec's §2.2 density resolution, adopted unchanged: glyph, name,
/// provenance word, closed badge. The whole row is one tap target
/// (`min-height` 64pt) — nothing inside it is independently tappable, so the
/// badge can never become a sub-44pt target. `PlacesList/` knows no
/// fetching, no persistence, and no router internals — it renders an entry
/// and reports a tap (TRD §2.3).
///
/// No tourist-heavy line on this row, by ruling (acceptance 2026-08-03,
/// `PAS-27`): `tourist-trap-flag` req 6 governs — the flag lives only in
/// the place-detail modal ("and nowhere else"), never on a Places row. This
/// row used to reserve a permanently-empty `EmptyView()` slot for a filler
/// that ruling ruled out; the slot was removed rather than left waiting for
/// a future that isn't coming.
struct PlacesListRow: View {
    let entry: PlacesListEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: entry.place.category.symbolName)
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.place.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        // Plain text, never a pill, present on every row —
                        // never omitted (TRD §4.4).
                        Text(entry.provenance.word)
                            .font(.caption)
                            .foregroundStyle(Color("MutedOnSurface"))
                        if entry.place.permanentlyClosed {
                            closedBadge
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PlacesRowLabel.label(
            name: entry.place.name,
            category: entry.place.category,
            provenance: entry.provenance,
            isClosed: entry.place.permanentlyClosed
        ))
    }

    /// The row's one emphasized element (design spec §2). Rendered **iff**
    /// `place.permanentlyClosed` — never red or alarm-toned (decision #38: a
    /// factual state about the place, not a judgment about its character).
    /// Never substitutes for the tourist-heavy flag, which never appears on
    /// this row at all (see the type doc comment above).
    private var closedBadge: some View {
        Label("Permanently closed", systemImage: "nosign")  // [ASSUMPTION] TRD §4.4
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color("BadgeSurface"), in: Capsule())
            .foregroundStyle(Color("BadgeOnSurface"))
    }
}
