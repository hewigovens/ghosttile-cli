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
        case failed(String)
    }

    @Published var cliStatus: CLIInstallStatus = .checking

    let expectedCLIVersion = BuildInfo.displayVersion

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
            "Installed"
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
            .green
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
        case .installed:
            "Reinstall CLI"
        case .checking, .notInstalled, .failed:
            "Install CLI"
        }
    }
}
