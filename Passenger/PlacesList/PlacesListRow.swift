import SwiftUI

/// One row of the Places list (TRD §4.4). Order top to bottom per the design
/// spec's §2.2 density resolution, adopted unchanged: glyph, name,
/// provenance word, closed badge, reserved tourist-heavy slot. The whole row
/// is one tap target (`min-height` 64pt) — nothing inside it is
/// independently tappable, so the badge and the (still-empty) flag line can
/// never become sub-44pt targets. `PlacesList/` knows no fetching, no
/// persistence, and no router internals — it renders an entry and reports a
/// tap (TRD §2.3).
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
                    touristHeavySlot
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
    /// `place.permanentlyClosed` — never substitutes for the tourist-heavy
    /// line below it, never red or alarm-toned (decision #38: a factual
    /// state about the place, not a judgment about its character).
    private var closedBadge: some View {
        Label("Permanently closed", systemImage: "nosign")  // [ASSUMPTION] TRD §4.4
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color("BadgeSurface"), in: Capsule())
            .foregroundStyle(Color("BadgeOnSurface"))
    }

    /// Reserved for T-035's tourist-heavy flag (TRD §4.4, D9), same
    /// construction as `PlaceDetailModal.touristTrapSlot`: `Place` carries
    /// no `isTouristTrap` in this task, so there is nothing to condition on.
    /// Do not fabricate a placeholder value here.
    @ViewBuilder
    private var touristHeavySlot: some View {
        EmptyView()
    }
}
