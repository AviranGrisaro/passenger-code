import SwiftUI

/// Per-Hood progress rows + the overall line (passport TRD §4.3, req 4/5).
/// `progress` already excludes undesignated Hoods (`PassportComposition`) —
/// nothing here filters again, so rendering everything it's handed is
/// correct by construction, and there is no "present at zero" branch to get
/// backwards.
struct PassportProgressList: View {
    let progress: [HoodProgress]
    let isOverallLocal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(progress) { entry in
                row(for: entry)
            }
            if !progress.isEmpty {
                overallLine
            }
        }
    }

    private func row(for entry: HoodProgress) -> some View {
        HStack {
            Text(entry.hood.name)
                .font(.body)
            Spacer()
            HStack(spacing: 6) {
                // Numerals against the threshold — "2 of 2" — never a bar
                // alone, never colour alone (design-principles.md §3, req
                // 5). The zero state ("0 of 2") is this same text with no
                // special-casing: no lock glyph, no error tone, no teaser.
                Text("\(entry.beenCount) of \(LocalStatus.threshold)")
                    .font(.subheadline.weight(.semibold))
                if entry.isLocal {
                    // Local carries a word *and* a glyph, never colour alone.
                    Label("Local", systemImage: "checkmark.seal.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PassportLabels.hoodProgress(
            hoodName: entry.hood.name, beenCount: entry.beenCount,
            threshold: LocalStatus.threshold, isLocal: entry.isLocal
        ))
    }

    /// Renders only when at least one Hood is designated — the caller
    /// already guarantees that by only reaching this branch when `progress`
    /// is non-empty.
    private var overallLine: some View {
        let localCount = progress.filter(\.isLocal).count
        return Text(PassportLabels.overall(localCount: localCount, designatedCount: progress.count))
            .font(.subheadline)
            .foregroundStyle(Color("MutedOnSurface"))
    }
}
