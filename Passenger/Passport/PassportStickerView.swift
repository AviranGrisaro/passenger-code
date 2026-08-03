import SwiftUI

/// One sticker (passport TRD §4.4). Not independently tappable in V1 (D10)
/// — the whole grid is a static display, so nothing inside it needs its own
/// ≥44pt guarantee beyond its own glyph circle, which is sized to it anyway.
struct PassportStickerView: View {
    let sticker: PassportSticker

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: sticker.shape.symbolName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundStyle(Color.accentColor)
            Text(sticker.place.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        // One element for VoiceOver, not two — the glyph carries no
        // independent meaning without the name (req 7, D12).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PassportLabels.sticker(placeName: sticker.place.name, shape: sticker.shape))
    }
}
