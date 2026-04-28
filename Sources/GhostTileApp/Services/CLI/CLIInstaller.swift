import AppKit
import Foundation
import GhostTileCore

enum CLIInstaller {
    static var isInstalled: Bool {
        CLIPaths.isInstalled
    }

    static func install() throws {
        guard let cliSource = CLIPaths.bundledCLI,
              let dylibSource = CLIPaths.bundledDylib
        else {
            throw CLIError.resourcesNotFound
        }

        do {
            try createInstallDirectoryIfNeeded()
            try removeInstalledFiles()
            try FileManager.default.copyItem(atPath: cliSource, toPath: CLIPaths.installedCLI)
            try FileManager.default.copyItem(atPath: dylibSource, toPath: CLIPaths.installedDylib)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: CLIPaths.installedCLI)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: CLIPaths.installedDylib)
        } catch {
            Log.error("CLI install failed: \(error)")
            throw CLIError.installFailed
        }
    }

    static func uninstall() throws {
        do {
            try removeInstalledFiles()
        } catch {
            Log.error("CLI uninstall failed: \(error)")
            throw CLIError.uninstallFailed
        }
    }

    static func installWithFeedback() {
        let wasInstalled = isInstalled
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")

        do {
            try install()
            alert.alertStyle = .informational
            alert.messageText = wasInstalled ? "Command Line Reinstalled" : "Command Line Installed"
            alert.informativeText = installSuccessMessage()
        } catch {
            alert.alertStyle = .warning
            alert.messageText = "Command Line Install Failed"
            alert.informativeText =
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        alert.runModal()
    }

    private static func createInstallDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(
            atPath: CLIPaths.installDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func removeInstalledFiles() throws {
        try removeFileIfExists(CLIPaths.installedCLI)
        try removeFileIfExists(CLIPaths.installedDylib)
    }

    private static func installSuccessMessage() -> String {
        let installed = "ghosttile and ghosthide.dylib are installed in \(CLIPaths.displayInstallDirectory)."

        guard !CLIEnvironment.directoryIsInPATH(CLIPaths.installDirectory) else {
            return installed
        }

        return """
        \(installed)

        \(CLIPaths.displayInstallDirectory) is not in your login shell PATH.

        \(CLIEnvironment.pathHint(for: CLIPaths.installDirectory))
        """
    }

    private static func removeFileIfExists(_ path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    enum CLIError: LocalizedError {
        case resourcesNotFound
        case installFailed
        case uninstallFailed

        var errorDescription: String? {
            switch self {
            case .resourcesNotFound:
                "CLI resources not found in the app bundle."
            case .installFailed:
                "Could not install the command line tools."
            case .uninstallFailed:
                "Could not uninstall the command line tools."
            }
        }
    }
}
