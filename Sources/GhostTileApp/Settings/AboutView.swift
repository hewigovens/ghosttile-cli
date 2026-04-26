import AppKit
import GhostTileCore
import SwiftUI

struct AboutView: View {
    @AppStorage("onboardingComplete") var onboardingComplete = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 128, height: 128)

                Text("GhostTile")
                    .font(.system(size: 16, weight: .bold))

                Text("Hide apps from Dock and Cmd+Tab.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text(versionLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                Text("Love GhostTile?")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button {
                        SponsorNudgeController.shared.openSponsorsPage()
                    } label: {
                        Label("Sponsor", systemImage: "heart.fill")
                    }
                    .controlSize(.small)

                    Button {
                        openGitHub()
                    } label: {
                        Label("Star on GitHub", systemImage: "star.fill")
                    }
                    .controlSize(.small)
                }
            }

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                Divider()

                Button("Show Welcome") {
                    onboardingComplete = false
                    NSApp.windows.first { $0.title == "About GhostTile" }?.close()
                }
                .controlSize(.small)
            }
        }
        .padding(24)
        .frame(width: 340, height: 420)
    }

    private var versionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? BuildInfo.version
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? BuildInfo.build
        return "Version \(version) · Build \(build)"
    }

    private func openGitHub() {
        guard let url = URL(string: "https://github.com/hewigovens/ghosttile-cli") else { return }
        NSWorkspace.shared.open(url)
    }
}
