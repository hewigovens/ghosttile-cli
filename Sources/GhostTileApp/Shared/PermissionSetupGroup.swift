import SwiftUI

struct PermissionSetupGroup<Content: View>: View {
    let title: String
    let subtitle: String
    var isCompact = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            VStack(alignment: .leading, spacing: isCompact ? 2 : 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(isCompact ? 1 : 2)
            }
            content
        }
        .padding(isCompact ? 0 : 12)
        .background {
            if !isCompact {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            }
        }
    }
}
