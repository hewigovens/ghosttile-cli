import SwiftUI

struct PermissionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isGranted = false
    var grantedTitle = "Granted"
    var actionTitle: String?
    var actionIsProminent = true
    var isCompact = false
    var accessibilityID: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: isCompact ? 11 : 14) {
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 13 : 16, style: .continuous)
                    .fill(tint.opacity(0.12))
                Image(systemName: systemImage)
                    .font(.system(size: isCompact ? 18 : 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: isCompact ? 42 : 52, height: isCompact ? 42 : 52)

            VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(isCompact ? 1 : 2)
            }

            Spacer()

            if isGranted {
                Label(grantedTitle, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.green.opacity(0.12)))
                    .accessibilityIdentifier("\(accessibilityID ?? title).status")
            } else if let actionTitle, let action {
                if actionIsProminent {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("\(accessibilityID ?? title).action")
                } else {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("\(accessibilityID ?? title).action")
                }
            }
        }
        .padding(isCompact ? 7 : 12)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID ?? title)
    }
}
