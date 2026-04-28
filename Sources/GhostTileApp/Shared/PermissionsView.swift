import AppKit
import SwiftUI

struct PermissionsView: View {
    var isCompact = false
    private let permissionRefreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    @State private var ghostTileAppManagementAllowed: Bool?
    @State private var screenRecordingAllowed = false
    @State private var cliInstalled = false
    @State private var permissionRefreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: isCompact ? 10 : 12) {
            PermissionSetupGroup(
                title: "GhostTile",
                subtitle: isCompact
                    ? "Required setup."
                    : "Required for preparing apps and showing Overview previews.",
                isCompact: isCompact
            ) {
                VStack(spacing: isCompact ? 8 : 10) {
                    PermissionCard(
                        title: "App Management",
                        subtitle: isCompact
                            ? "Prepare and restore app bundles."
                            : "Lets GhostTile prepare and restore app bundles.",
                        systemImage: "eye.slash.circle.fill",
                        tint: .blue,
                        isGranted: ghostTileAppManagementAllowed == true,
                        actionTitle: "Grant",
                        isCompact: isCompact,
                        accessibilityID: "permissions.ghosttile.appManagement",
                        action: {
                            PermissionGuidanceController.shared.present(
                                pane: .appManagement,
                                target: .ghostTile()
                            )
                        }
                    )
                    PermissionCard(
                        title: "Screen & System Audio Recording",
                        subtitle: isCompact
                            ? "Live window thumbnails in Overview."
                            : "Enables live window thumbnails in Overview.",
                        systemImage: "rectangle.on.rectangle",
                        tint: .orange,
                        isGranted: screenRecordingAllowed,
                        actionTitle: "Grant",
                        isCompact: isCompact,
                        accessibilityID: "permissions.ghosttile.screenRecording",
                        action: {
                            PermissionGuidanceController.shared.present(
                                pane: .screenRecording,
                                target: .ghostTile()
                            )
                        }
                    )
                }
            }

            PermissionSetupGroup(
                title: "Terminal",
                subtitle: isCompact
                    ? "Optional recovery tools."
                    : "Optional recovery setup for protected apps and command line workflows.",
                isCompact: isCompact
            ) {
                VStack(spacing: isCompact ? 8 : 10) {
                    PermissionCard(
                        title: "App Management",
                        subtitle: isCompact
                            ? "Run manual sudo recovery commands."
                            : "Lets Terminal run manual `sudo ghosttile ...` recovery commands.",
                        systemImage: "terminal.fill",
                        tint: .purple,
                        actionTitle: "Grant",
                        actionIsProminent: false,
                        isCompact: isCompact,
                        accessibilityID: "permissions.terminal.appManagement",
                        action: {
                            PermissionGuidanceController.shared.present(
                                pane: .appManagement,
                                target: .terminal()
                            )
                        }
                    )
                    PermissionCard(
                        title: "Command Line Tool",
                        subtitle: isCompact
                            ? "Install ghosttile in \(CLIPaths.displayInstallDirectory)."
                            : "Installs ghosttile and support files in \(CLIPaths.displayInstallDirectory).",
                        systemImage: "hammer.fill",
                        tint: .green,
                        isGranted: cliInstalled,
                        grantedTitle: "Installed",
                        actionTitle: "Install",
                        actionIsProminent: false,
                        isCompact: isCompact,
                        accessibilityID: "permissions.cli.install",
                        action: {
                            CLIInstaller.installWithFeedback()
                            cliInstalled = CLIInstaller.isInstalled
                        }
                    )
                }
            }
        }
        .onAppear(perform: refreshPermissionStatus)
        .onDisappear {
            permissionRefreshTask?.cancel()
            permissionRefreshTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
        .onReceive(permissionRefreshTimer) { _ in
            refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() {
        permissionRefreshTask?.cancel()
        cliInstalled = CLIInstaller.isInstalled

        permissionRefreshTask = Task { @MainActor in
            let appManagementTask = Task.detached(priority: .userInitiated) {
                AppManagementPermissionStatusReader.currentProcessIsAllowed()
            }
            let screenCaptureAllowed = await ScreenCapturePermissionStatusReader.isAllowed()
            let appManagementAllowed = await appManagementTask.value

            guard !Task.isCancelled else { return }

            ghostTileAppManagementAllowed = appManagementAllowed
            screenRecordingAllowed = screenCaptureAllowed
        }
    }
}
