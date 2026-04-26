import SwiftUI

struct PermissionGuidanceOverlayView: View {
    let pane: SystemSettingsPane
    let target: PermissionGuidanceTarget
    let onClose: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.78))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 0.5)

            VStack(spacing: 13) {
                header
                    .padding(.leading, 6)
                    .padding(.trailing, -4)

                PermissionDragSourceRepresentable(target: target)
                    .frame(height: 48)
            }
            .padding(.top, 15)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Drag \(target.fileName) into the list above")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .labelColor).opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("Then turn on \(pane.title).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}
