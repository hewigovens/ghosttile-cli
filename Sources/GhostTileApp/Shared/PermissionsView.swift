import AppKit
import SwiftUI

struct PermissionsView: View {
    var body: some View {
        VStack(spacing: 10) {
            PermissionCard(
                title: "GhostTile",
                subtitle: "Needed to prepare apps for hiding and restoration.",
                systemImage: "eye.slash.circle.fill",
                tint: .blue,
                actionTitle: "Grant",
                action: {
                    PermissionGuidanceController.shared.present(
                        pane: .appManagement,
                        target: .ghostTile()
                    )
                }
            )
            PermissionCard(
                title: "Terminal",
                subtitle: "Needed when a protected app must be handled with `sudo ghosttile …`.",
                systemImage: "terminal.fill",
                tint: .purple,
                actionTitle: "Grant",
                action: {
                    PermissionGuidanceController.shared.present(
                        pane: .appManagement,
                        target: .terminal()
                    )
                }
            )
            PermissionCard(
                title: "Screen & System Audio Recording",
                subtitle: "Lets Overview capture live window thumbnails for managed apps.",
                systemImage: "rectangle.on.rectangle",
                tint: .orange,
                actionTitle: "Grant",
                action: {
                    PermissionGuidanceController.shared.present(
                        pane: .screenRecording,
                        target: .ghostTile()
                    )
                }
            )
        }
    }
}
