import AppKit
import SwiftUI

enum SystemSettings {
    static func openAppManagement() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openScreenCapture() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct PermissionsView: View {
    var body: some View {
        VStack(spacing: 10) {
            PermissionCard(
                title: "GhostTile",
                subtitle: "Needed to prepare apps for hiding and restoration.",
                systemImage: "eye.slash.circle.fill",
                tint: .blue,
                actionTitle: "Grant",
                action: SystemSettings.openAppManagement
            )
            PermissionCard(
                title: "Terminal",
                subtitle: "Needed when a protected app must be handled with `sudo ghosttile …`.",
                systemImage: "terminal.fill",
                tint: .purple,
                actionTitle: "Grant",
                action: SystemSettings.openAppManagement
            )
            PermissionCard(
                title: "Screen & System Audio Recording",
                subtitle: "Lets Overview capture live window thumbnails for managed apps.",
                systemImage: "rectangle.on.rectangle",
                tint: .orange,
                actionTitle: "Grant",
                action: SystemSettings.openScreenCapture
            )
        }
    }
}
