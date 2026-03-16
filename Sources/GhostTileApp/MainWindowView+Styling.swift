import AppKit
import GhostTileCore
import SwiftUI

extension MainWindowView {
    var windowBackground: some View {
        ZStack {
            if isDarkMode {
                Rectangle()
                    .fill(.ultraThinMaterial)
            } else {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
            }

            LinearGradient(
                colors: [
                    Color.blue.opacity(isDarkMode ? 0.12 : 0.07),
                    Color.clear,
                    Color.orange.opacity(isDarkMode ? 0.05 : 0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(isDarkMode ? 0.12 : 0.07))
                .frame(width: 480, height: 480)
                .blur(radius: 110)
                .offset(x: -240, y: -220)

            Circle()
                .fill(Color.orange.opacity(isDarkMode ? 0.08 : 0.04))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 260, y: 240)

            oldGhostTileWatermark
                .frame(width: 108, height: 108)
                .opacity(isDarkMode ? 0.08 : 0.06)
                .rotationEffect(.degrees(-8))
                .offset(x: 440, y: 300)
        }
        .ignoresSafeArea()
    }

    func sectionBackground(isDropTargeted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(isDarkMode ? Color.black.opacity(0.18) : Color.white.opacity(0.54))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        isDropTargeted
                            ? Color.accentColor.opacity(0.34)
                            : (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06)),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isDarkMode ? 0.12 : 0.05), radius: 24, y: 10)
    }

    var sidebarBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(isDarkMode ? Color.black.opacity(0.16) : Color.white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isDarkMode ? 0.1 : 0.05), radius: 20, y: 8)
    }

    func sectionHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    func statPill(title: String, value: Int, systemImage: String) -> some View {
        Label {
            HStack(spacing: 4) {
                Text(title)
                Text("\(value)")
                    .foregroundStyle(.primary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
        )
        .overlay(
            Capsule()
                .stroke(
                    isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    var ghostImage: some View {
        let url = BundledResources.resourceURL(named: "ghost-icon.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "eye.slash.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var oldGhostTileWatermark: some View {
        let url = BundledResources.resourceURL(named: "appIcon-old.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .saturation(isDarkMode ? 0.2 : 0.1)
        }
    }
}
