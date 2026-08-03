import SwiftUI

/// The two quick-filter chips (TRD §4.5, §4.8, D8) — exactly two, because
/// `PlaceCategory.allCases` has exactly two elements and no `.other`.
struct CategoryChipRow: View {
    let filter: CategoryFilter
    let onToggle: (PlaceCategory) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PlaceCategory.allCases, id: \.self) { category in
                CategoryChip(
                    category: category,
                    isSelected: filter.isActive(category),
                    action: { onToggle(category) }
                )
            }
        }
    }
}

/// **Selected state without colour** (PRD req 3 bullet 5): a selected chip
/// carries a leading checkmark glyph and a heavier weight; an unselected one
/// carries neither. The distinction survives a greyscale screenshot.
private struct CategoryChip: View {
    let category: PlaceCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(category.displayName)
                    // Mirrors `SearchResultRow`'s existing pattern (PRD req 8
                    // bullet 4, added at T-038/PAS-29's second acceptance
                    // pass, F2): without this, the largest accessibility text
                    // size compresses "Eat & Drink"/"Things to do" inside the
                    // fixed, non-wrapping `HStack` in `CategoryChipRow`
                    // instead of letting the label wrap and the chip grow.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)  // Fitts's Law minimum (design-principles.md §2)
            .background(
                isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
