import AppKit
import GhostTileCore
import SwiftUI

extension OnboardingView {
    var onboardingBackground: some View {
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
                .frame(width: 420, height: 420)
                .blur(radius: 100)
                .offset(x: -220, y: -200)

            Circle()
                .fill(Color.orange.opacity(isDarkMode ? 0.08 : 0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 230, y: 220)

            oldGhostTileWatermark
                .frame(width: 110, height: 110)
                .opacity(isDarkMode ? 0.08 : 0.06)
                .rotationEffect(.degrees(-10))
                .offset(x: 225, y: 185)
        }
        .ignoresSafeArea()
    }

    var panelFill: Color {
        isDarkMode ? Color.black.opacity(0.18) : Color.white.opacity(0.56)
    }

    var panelStroke: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var indicatorFill: Color {
        isDarkMode ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    var heroTileFill: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.74)
    }

    func onboardingPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
            )
            .overlay(
                Capsule()
                    .stroke(panelStroke, lineWidth: 1)
            )
    }

    @ViewBuilder
    var oldIcon: some View {
        let url = BundledResources.resourceURL(named: "appIcon-old.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }

    @ViewBuilder
    var newIcon: some View {
        let url = BundledResources.resourceURL(named: "appIcon-new.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
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
