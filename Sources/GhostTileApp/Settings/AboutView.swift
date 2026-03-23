import AppKit
import GhostTileCore
import SwiftUI

struct AboutView: View {
    @AppStorage("onboardingComplete") var onboardingComplete = true

    var body: some View {
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

            HStack(spacing: 8) {
                Text("Love GhostTile?")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button {
                    SponsorNudgeController.shared.openSponsorsPage()
                } label: {
                    Label("Sponsor", systemImage: "heart.fill")
                }
                .controlSize(.small)
            }

            Divider().padding(.horizontal, 20)

            Button("Show Welcome") {
                onboardingComplete = false
                NSApp.windows.first { $0.title == "About GhostTile" }?.close()
            }
            .controlSize(.small)
        }
        .padding(24)
        .frame(width: 300)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var versionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? BuildInfo.version
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? BuildInfo.build
        return "Version \(version) · Build \(build)"
    }
}
