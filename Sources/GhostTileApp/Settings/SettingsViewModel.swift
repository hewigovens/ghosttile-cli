import AppKit
import Foundation
import GhostTileCore
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    enum CLIInstallStatus {
        case checking
        case notInstalled
        case installed
        case updateAvailable(String)
        case failed(String)
    }

    @Published var cliStatus: CLIInstallStatus = .checking
    @Published var cliInstallDirectoryIsInPATH = true

    let expectedCLIVersion = BuildInfo.cliDisplayVersion

    var versionTapCount = 0
    var lastVersionTapAt = Date.distantPast

    var displayLogPath: String {
        (Log.logPath as NSString).abbreviatingWithTildeInPath
    }

    var cliStatusText: String {
        switch cliStatus {
        case .checking:
            "Checking"
        case .installed:
            cliInstallDirectoryIsInPATH ? "Installed" : "Add to PATH"
        case .updateAvailable:
            "Update Available"
        case .notInstalled:
            "Optional"
        case .failed:
            "Needs Attention"
        }
    }

    var cliStatusColor: Color {
        switch cliStatus {
        case .checking:
            .secondary
        case .installed:
            cliInstallDirectoryIsInPATH ? .green : .orange
        case .updateAvailable:
            .blue
        case .notInstalled:
            .orange
        case .failed:
            .red
        }
    }

    func setShowInDock(_ show: Bool) {
        if show {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var cliActionTitle: String {
        switch cliStatus {
        case .installed, .updateAvailable:
            "Reinstall CLI"
        case .checking, .notInstalled, .failed:
            "Install CLI"
        }
    }

    var cliPathHint: String {
        CLIEnvironment.pathHint(for: CLIPaths.installDirectory)
    }
}
