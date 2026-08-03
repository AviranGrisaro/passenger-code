import SwiftUI

/// The query text field, with a real visible label above it — placeholder
/// text standing in for a label is banned (`design-principles.md` §3), and a
/// UI test needs a static label element distinct from the field's own prompt
/// to assert against (TRD §9 row 2e).
struct SearchFieldRow: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Search")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Places, Hoods, or a keyword", text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
        }
    }
}
