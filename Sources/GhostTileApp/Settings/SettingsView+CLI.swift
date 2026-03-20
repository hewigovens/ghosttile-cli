import GhostTileCore
import ServiceManagement
import SwiftUI

extension SettingsViewModel {
    func checkCLIInstalled() {
        let cliInstalled = FileManager.default.fileExists(atPath: CLIPaths.installedCLI)
        let dylibInstalled = FileManager.default.fileExists(atPath: CLIPaths.installedDylib)

        if cliInstalled && dylibInstalled {
            do {
                let installedVersion = try AppManager.run(CLIPaths.installedCLI, ["--version"])
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

    private func removeInstalledFiles() throws {
        try removeFileIfExists(CLIPaths.installedCLI)
        try removeFileIfExists(CLIPaths.installedDylib)
    }

    private func removeInstalledFilesViaAdmin() throws {
        if FileManager.default.fileExists(atPath: CLIPaths.installedCLI) {
            try HelperClient.removeFile(atPath: CLIPaths.installedCLI)
        }
        if FileManager.default.fileExists(atPath: CLIPaths.installedDylib) {
            try HelperClient.removeFile(atPath: CLIPaths.installedDylib)
        }
    }

    private func removeFileIfExists(_ path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    func uninstallCLI() {
        do {
            try removeInstalledFiles()
            cliStatus = .notInstalled
            return
        } catch {
            Log.info("Direct CLI uninstall failed: \(error)")
        }
        do {
            try removeInstalledFilesViaAdmin()
            cliStatus = .notInstalled
        } catch {
            Log.error("CLI uninstall failed: \(error)")
            cliStatus = .failed("Uninstall failed")
        }
    }

    func installCLI() {
        guard let cliSource = CLIPaths.bundledCLI,
              let dylibSource = CLIPaths.bundledDylib
        else {
            cliStatus = .failed("CLI resources not found in app bundle")
            return
        }

        do {
            try removeInstalledFiles()
            try FileManager.default.copyItem(atPath: cliSource, toPath: CLIPaths.installedCLI)
            try FileManager.default.copyItem(atPath: dylibSource, toPath: CLIPaths.installedDylib)
            cliStatus = .installed
            return
        } catch {
            Log.info("Direct CLI install failed: \(error)")
        }

        do {
            try HelperClient.copyFile(from: cliSource, to: CLIPaths.installedCLI)
            try HelperClient.copyFile(from: dylibSource, to: CLIPaths.installedDylib)
            cliStatus = .installed
        } catch {
            Log.error("CLI install failed: \(error)")
            cliStatus = .failed("Install failed — see manual command below")
        }
    }

    func setLaunchAtLogin(_ enabled: Bool, launchAtLogin: Binding<Bool>) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
                launchAtLogin.wrappedValue = enabled
            } catch {
                launchAtLogin.wrappedValue = !enabled
            }
        }
    }

    func syncLaunchAtLoginState(launchAtLogin: Binding<Bool>) {
        if #available(macOS 13.0, *) {
            launchAtLogin.wrappedValue = SMAppService.mainApp.status == .enabled
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
