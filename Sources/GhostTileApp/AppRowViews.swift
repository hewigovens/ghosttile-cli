import LSAppCategory
import SwiftUI

struct RunningAppSidebarRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let app: AppViewModel.AppItem
    let isLoading: Bool
    let onHide: () -> Void

    @State private var hovering = false

    private var isDarkMode: Bool { colorScheme == .dark }
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
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(iconTileFillColor)
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size - 12, height: size - 12)
        }
        .frame(width: size, height: size)
    }
}

struct ManagedAppCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let app: AppViewModel.AppItem
    let isLoading: Bool
    let onOpen: () -> Void
    let onPrimaryAction: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    private var isDarkMode: Bool { colorScheme == .dark }
    private var cardFillColor: Color {
        isDarkMode ? Color.white.opacity(0.06) : Color.white.opacity(0.52)
    }

    private var cardStrokeColor: Color {
        if isDarkMode {
            return Color.white.opacity(hovering ? 0.14 : 0.08)
        }

        return Color.black.opacity(hovering ? 0.08 : 0.05)
    }

    private var cardShadowColor: Color {
        Color.black.opacity(isDarkMode ? 0.12 : 0.05)
    }

    private var heroGradientColors: [Color] {
        [
            Color.blue.opacity(isDarkMode ? 0.18 : 0.12),
            isDarkMode ? Color.black.opacity(0.58) : Color.white.opacity(0.56),
            Color.orange.opacity(isDarkMode ? 0.06 : 0.03),
        ]
    }

    private var heroOverlayColor: Color {
        Color.white.opacity(isDarkMode ? 0.03 : 0.14)
    }

    private var statusBadgeFillColor: Color {
        isDarkMode ? Color.black.opacity(0.18) : Color.white.opacity(0.6)
    }

    private var iconTileStrokeColor: Color {
        isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    private var statusLabel: String {
        if !app.isRunning {
            return "Not Running"
        }

        return app.isHiddenFromDock ? "Hidden from Dock" : "Visible in Dock"
    }

    private var statusColor: Color {
        if !app.isRunning {
            return .secondary
        }

        return app.isHiddenFromDock ? .orange : .green
    }

    private var primaryActionTitle: String {
        if !app.isRunning {
            return "Launch"
        }

        return app.isHiddenFromDock ? "Show" : "Hide"
    }

    private var primaryActionIcon: String {
        if !app.isRunning {
            return "play.fill"
        }

        return app.isHiddenFromDock ? "eye" : "eye.slash"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                heroBackground

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        statusBadge
                        Spacer()
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Spacer()
                            iconTile(size: 82)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                    }
                }
                .padding(16)
            }
            .frame(height: 172)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(hovering ? 0.18 : 0.08), lineWidth: 1)
            )

            HStack(alignment: .center, spacing: 10) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                } else {
                    Button(action: onPrimaryAction) {
                        Label(primaryActionTitle, systemImage: primaryActionIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Reveal and activate")

                    Spacer()
                }

                Button(action: onReveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reveal in Finder")

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Remove from GhostTile")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 22, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: onOpen)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contextMenu {
            Button("Reveal and Activate", action: onOpen)
            Button("Reveal in Finder", action: onReveal)
            Divider()
            Button("Remove from GhostTile", action: onRemove)
        }
    }

    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: heroGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(heroOverlayColor)

            Circle()
                .fill(statusColor.opacity(0.24))
                .frame(width: 140, height: 140)
                .blur(radius: 28)
                .offset(x: 0, y: 8)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(statusColor == .secondary ? .secondary : statusColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusBadgeFillColor)
        )
    }

    private func iconTile(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(iconTileStrokeColor, lineWidth: 1)
                )
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size - 16, height: size - 16)
        }
        .frame(width: size, height: size)
    }
}
