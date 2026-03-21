import AppKit
import SwiftUI

struct OverviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let app: ManagedAppItem
    let thumbnail: NSImage?
    let isSelected: Bool
    let actions: ManagedAppActions
    var onTap: (() -> Void)?

    @State private var hovering = false
    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardFillColor: Color {
        isDarkMode ? Color.black.opacity(0.22) : Color.white.opacity(0.56)
    }

    private var cardStrokeColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }

        return isDarkMode ? Color.white.opacity(hovering ? 0.12 : 0.05) : Color.black.opacity(hovering ? 0.08 : 0.05)
    }

    private var previewStrokeColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.75)
        }

        return isDarkMode ? Color.white.opacity(hovering ? 0.18 : 0.08) : Color.black.opacity(hovering ? 0.08 : 0.05)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                thumbnailBody

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .center, spacing: 10) {
                    IconTileView(
                        icon: app.icon,
                        size: 40,
                        cornerRadius: 10,
                        iconInset: 12,
                        fill: iconChipFill
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(app.id)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .padding(14)
            }
            .frame(height: 154)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(previewStrokeColor, lineWidth: isSelected ? 2 : 1)
            )

            HStack(spacing: 8) {
                statusPill
                Spacer()
                actionButtons
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(isDarkMode ? 0.16 : 0.05), radius: 20, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { actions.open(app); onTap?() }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contextMenu {
            if app.isRunning {
                if app.isHiddenFromDock {
                    Button("Show in Dock", action: { actions.show(app) })
                } else {
                    Button("Hide from Dock", action: { actions.hide(app) })
                }
            }
            Button("Reveal in Finder", action: { actions.reveal(app) })
            Divider()
            Button("Remove from GhostTile", action: { actions.remove(app) })
        }
    }

    @ViewBuilder
    private var thumbnailBody: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isDarkMode ? Color.black.opacity(0.75) : Color.white.opacity(0.64))
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(isDarkMode ? 0.25 : 0.14),
                        isDarkMode ? Color.black.opacity(0.7) : Color.white.opacity(0.56),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .opacity(0.88)
            }
        }
    }

    private var iconChipFill: AnyShapeStyle {
        isDarkMode ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.74))
    }

    private var statusPill: some View {
        Text(statusText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.14))
            )
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if app.isRunning {
                Button {
                    app.isHiddenFromDock ? actions.show(app) : actions.hide(app)
                } label: {
                    Image(systemName: app.isHiddenFromDock ? "eye" : "eye.slash")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Button {
                actions.reveal(app)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)

            Button {
                actions.remove(app)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        app.statusText
    }

    private var statusColor: Color {
        app.statusColor
    }
}
