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
