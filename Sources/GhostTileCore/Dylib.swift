import Foundation

public enum Dylib {
    public static let installName = MachOEditor.ghosthideInstallName

    /// Path to the bundled dylib in the app's Resources or next to the CLI binary.
    public static var bundledPath: String? {
        let execURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])

        // App bundle: Contents/MacOS/GhostTile → Contents/Resources/ghosthide.dylib
        let appPath = execURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/ghosthide.dylib").path
        if FileManager.default.fileExists(atPath: appPath) { return appPath }

        // CLI: same directory as the binary
        let cliPath = execURL.deletingLastPathComponent()
            .appendingPathComponent("ghosthide.dylib").path
        if FileManager.default.fileExists(atPath: cliPath) { return cliPath }

        return nil
    }

    public static func bundleInstallPath(forAppPath appPath: String) -> String {
        URL(fileURLWithPath: appPath)
            .appendingPathComponent("Contents/Frameworks/ghosthide.dylib").path
    }

    /// Returns the packaged dylib path for the app bundle or installed CLI.
    public static func ensureDylib() throws -> String {
        if let path = bundledPath { return path }
        throw GhostTileError(
            "ghosthide.dylib is missing. Reinstall GhostTile or use Settings -> Reinstall CLI to install the companion dylib."
        )
    }
}
