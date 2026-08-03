import SwiftUI

/// The sticker grid, filed under a single city header (passport TRD §4.4,
/// D11). V1 has exactly one city — no `city` field exists on `Place`/`Hood`
/// and none is added here (D11) — so this renders one static header and no
/// grouping axis.
struct PassportAlbum: View {
    let stickers: [PassportSticker]

    private static let columns = [GridItem(.adaptive(minimum: 72), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // [ASSUMPTION] TRD §4.4, D11 — one city, one static header.
            Text("Tel Aviv")
                .font(.headline)
                .foregroundStyle(Color("MutedOnSurface"))
                .accessibilityAddTraits(.isHeader)

            if stickers.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: Self.columns, spacing: 16) {
                    ForEach(stickers) { sticker in
                        PassportStickerView(sticker: sticker)
                    }
                }
            }
        }
    }

    /// Icon + one line naming what earns a sticker + no CTA that leaves the
    /// screen — plain, never an error, never a spinner (`design-principles.md`
    /// §4, PRD req 5 bullet 3).
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.largeTitle)
                .foregroundStyle(Color("MutedOnSurface"))
            Text("Visit a place to earn its sticker here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
