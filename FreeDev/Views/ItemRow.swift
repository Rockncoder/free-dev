import SwiftUI

struct ItemRow: View {
    let item: CleanupItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(item.selected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!item.exists)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(item.exists ? .primary : .secondary)
                    if item.safety == .caution {
                        Text("caution")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    if let note = item.note {
                        Text(note)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Text(item.exists ? ByteFormat.string(item.reclaimableBytes) : "—")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(item.exists ? .primary : .secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(item.selected ? Color.accentColor.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { if item.exists { onToggle() } }
        .opacity(item.exists ? 1 : 0.5)
    }
}
