import AppKit
import GhostTileCore
import ServiceManagement
import SwiftUI

extension SettingsView {
    var bundledCLIPath: String? {
        let path = BundledResources.resourcePath(named: "ghosttile-cli")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    var bundledDylibPath: String? {
        let path = BundledResources.resourcePath(named: "ghosthide.dylib")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    var displayLogPath: String {
        (Log.logPath as NSString).abbreviatingWithTildeInPath
    }

    var cliStatusText: String {
        switch cliStatus {
        case .checking:
            return "Checking"
        case .installed:
            return "Installed"
        case .notInstalled:
            return "Optional"
        case .failed:
            return "Needs Attention"
        }
    }

    var cliStatusColor: Color {
        switch cliStatus {
        case .checking:
            return .secondary
        case .installed:
            return .green
        case .notInstalled:
            return .orange
        case .failed:
            return .red
        }
    }

    var cliActionTitle: String {
        switch cliStatus {
        case .installed:
            return "Reinstall CLI"
        case .checking, .notInstalled, .failed:
            return "Install CLI"
        }
    }

    func checkCLIInstalled() {
        let cliInstalled = FileManager.default.fileExists(atPath: cliInstallPath)
        let dylibInstalled = FileManager.default.fileExists(atPath: cliDylibInstallPath)

        if cliInstalled && dylibInstalled {
            do {
                let installedVersion = try AppManager.run(cliInstallPath, ["--version"])
                if installedVersion == expectedCLIVersion {
                    cliStatus = .installed
                } else {
                    cliStatus = .failed(
                        "Installed CLI is \(installedVersion). This app bundles \(expectedCLIVersion). Reinstall CLI to update it."
                    )
                }
            } catch {
                cliStatus = .failed("Could not verify installed CLI version. Reinstall CLI to refresh it.")
            }
        } else if cliInstalled || dylibInstalled {
            cliStatus = .failed("CLI install is incomplete. Reinstall the CLI to restore the support files.")
        } else {
            cliStatus = .notInstalled
        }
    }

    func uninstallCLI() {
        do {
            if FileManager.default.fileExists(atPath: cliInstallPath) {
                try FileManager.default.removeItem(atPath: cliInstallPath)
            }
            if FileManager.default.fileExists(atPath: cliDylibInstallPath) {
                try FileManager.default.removeItem(atPath: cliDylibInstallPath)
            }
            cliStatus = .notInstalled
            return
        } catch {
            Log.info("Direct CLI uninstall failed: \(error)")
        }
        do {
            if FileManager.default.fileExists(atPath: cliInstallPath) {
                try HelperClient.removeFile(atPath: cliInstallPath)
            }
            if FileManager.default.fileExists(atPath: cliDylibInstallPath) {
                try HelperClient.removeFile(atPath: cliDylibInstallPath)
            }
            cliStatus = .notInstalled
        } catch {
            Log.error("CLI uninstall failed: \(error)")
            cliStatus = .failed("Uninstall failed")
        }
    }

    func installCLI() {
        guard let cliSource = bundledCLIPath,
              let dylibSource = bundledDylibPath
        else {
            cliStatus = .failed("CLI resources not found in app bundle")
            return
        }

        do {
            if FileManager.default.fileExists(atPath: cliInstallPath) {
                try FileManager.default.removeItem(atPath: cliInstallPath)
            }
            if FileManager.default.fileExists(atPath: cliDylibInstallPath) {
                try FileManager.default.removeItem(atPath: cliDylibInstallPath)
            }
            try FileManager.default.copyItem(atPath: cliSource, toPath: cliInstallPath)
            try FileManager.default.copyItem(atPath: dylibSource, toPath: cliDylibInstallPath)
            cliStatus = .installed
            return
        } catch {
            Log.info("Direct CLI install failed: \(error)")
        }

        do {
            try HelperClient.copyFile(from: cliSource, to: cliInstallPath)
            try HelperClient.copyFile(from: dylibSource, to: cliDylibInstallPath)
            cliStatus = .installed
        } catch {
            Log.error("CLI install failed: \(error)")
            cliStatus = .failed("Install failed — see manual command below")
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
                launchAtLogin = enabled
            } catch {
                launchAtLogin = !enabled
            }
        }
    }

    func syncLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func openLogInConsole() {
        if !FileManager.default.fileExists(atPath: Log.logPath) {
            FileManager.default.createFile(atPath: Log.logPath, contents: Data())
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Console", Log.logPath]

        do {
            try process.run()
        } catch {
            Log.error("Failed to open log in Console: \(error)")
        }
    }

    func handleVersionTap() {
        let now = Date()
        if now.timeIntervalSince(lastVersionTapAt) > 1.2 {
            versionTapCount = 0
        }

        versionTapCount += 1
        lastVersionTapAt = now

        if versionTapCount >= 5 {
            versionTapCount = 0
            SponsorNudgeController.shared.presentForTesting()
        }
    }
}
