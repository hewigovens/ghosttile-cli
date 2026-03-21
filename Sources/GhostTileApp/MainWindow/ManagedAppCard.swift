import SwiftUI

struct ManagedAppCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let app: ManagedAppItem
    let isLoading: Bool
    let actions: ManagedAppActions
    let onPrimaryAction: () -> Void

    @State private var hovering = false

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

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
        app.statusText
    }

    private var statusColor: Color {
        app.statusColor
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

                    Button {
                        actions.open(app)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Reveal and activate")

                    Spacer()
                }

                Button {
                    actions.reveal(app)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reveal in Finder")

                Button {
                    actions.remove(app)
                } label: {
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
        .onTapGesture(perform: { actions.open(app) })
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contextMenu {
            Button("Reveal and Activate", action: { actions.open(app) })
            Button("Reveal in Finder", action: { actions.reveal(app) })
            Divider()
            Button("Remove from GhostTile", action: { actions.remove(app) })
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
        IconTileView(
            icon: app.icon,
            size: size,
            cornerRadius: 18,
            iconInset: 16,
            fill: AnyShapeStyle(.ultraThinMaterial),
            strokeColor: iconTileStrokeColor
        )
    }
}
