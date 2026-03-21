import Foundation

public enum Dylib {
    public static let installName = MachOEditor.ghosthideInstallName

    public static var bundledPath: String? {
        let appPath = BundledResources.resourcePath(named: "ghosthide.dylib")
        if FileManager.default.fileExists(atPath: appPath) { return appPath }

        let cliPath = BundledResources.executableURL.deletingLastPathComponent()
            .appendingPathComponent("ghosthide.dylib").path
        if FileManager.default.fileExists(atPath: cliPath) { return cliPath }

        return nil
    }

    public static func bundleInstallPath(forAppPath appPath: String) -> String {
        URL(fileURLWithPath: appPath)
            .appendingPathComponent("Contents/Frameworks/ghosthide.dylib").path
    }

    public static func ensureDylib() throws -> String {
        if let path = bundledPath { return path }
        throw GhostTileError(
            "ghosthide.dylib is missing. Reinstall GhostTile or use Settings -> Reinstall CLI to install the companion dylib."
        )
    }
}
