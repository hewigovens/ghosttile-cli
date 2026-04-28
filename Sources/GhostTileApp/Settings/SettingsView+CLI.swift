import GhostTileCore
import ServiceManagement
import SwiftUI

extension SettingsViewModel {
    func checkCLIInstalled() {
        let cliInstalled = FileManager.default.fileExists(atPath: CLIPaths.installedCLI)
        let dylibInstalled = FileManager.default.fileExists(atPath: CLIPaths.installedDylib)

        if CLIPaths.isInstalled {
            cliInstallDirectoryIsInPATH = CLIEnvironment.directoryIsInPATH(CLIPaths.installDirectory)

            do {
                let installedVersion = try AppManager.run(CLIPaths.installedCLI, ["--version"])
                if installedVersion == expectedCLIVersion {
                    cliStatus = .installed
                } else {
                    cliStatus = .updateAvailable(installedVersion)
                }
            } catch {
                cliStatus = .failed("Could not verify installed CLI version. Reinstall CLI to refresh it.")
            }
        } else if cliInstalled || dylibInstalled {
            cliInstallDirectoryIsInPATH = CLIEnvironment.directoryIsInPATH(CLIPaths.installDirectory)
            cliStatus = .failed("CLI install is incomplete. Reinstall the CLI to restore the support files.")
        } else {
            cliInstallDirectoryIsInPATH = CLIEnvironment.directoryIsInPATH(CLIPaths.installDirectory)
            cliStatus = .notInstalled
        }
    }

    func uninstallCLI() {
        do {
            try CLIInstaller.uninstall()
            cliInstallDirectoryIsInPATH = CLIEnvironment.directoryIsInPATH(CLIPaths.installDirectory)
            cliStatus = .notInstalled
        } catch {
            cliStatus = .failed(
                (error as? LocalizedError)?.errorDescription ?? "Uninstall failed"
            )
        }
    }

    func installCLI() {
        do {
            try CLIInstaller.install()
            checkCLIInstalled()
        } catch {
            cliStatus = .failed(
                (error as? LocalizedError)?.errorDescription ?? "Install failed"
            )
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
