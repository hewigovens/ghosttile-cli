import LSAppCategory
import SwiftUI

struct RunningAppSidebarRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let app: ManagedAppItem
    let isLoading: Bool
    let onHide: () -> Void

    @State private var hovering = false

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var rowFillColor: Color {
        if hovering {
            return isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.74)
        }

        return isDarkMode ? Color.white.opacity(0.04) : Color.white.opacity(0.56)
    }

    private var rowStrokeColor: Color {
        if isDarkMode {
            return Color.white.opacity(hovering ? 0.12 : 0.06)
        }

        return Color.black.opacity(hovering ? 0.08 : 0.05)
    }

    private var iconTileFillColor: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.78)
    }

    var body: some View {
        HStack(spacing: 12) {
            iconTile(size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if app.category != .other {
                        Image(systemName: app.category.sfSymbol)
                            .font(.system(size: 9, weight: .medium))
                        Text(app.category.description)
                    } else {
                        Text(app.id)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    onHide()
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Hide from Dock")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }

    private func iconTile(size: CGFloat) -> some View {
        IconTileView(
            icon: app.icon,
            size: size,
            cornerRadius: 14,
            iconInset: 12,
            fill: AnyShapeStyle(iconTileFillColor)
        )
    }
}
