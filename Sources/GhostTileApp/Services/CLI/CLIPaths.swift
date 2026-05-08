import Foundation
import GhostTileCore

enum CLIPaths {
    static let executableName = "ghosttile"
    static let dylibName = "ghosthide.dylib"

    static var installDirectory: String {
        "\(NSHomeDirectory())/.local/bin"
    }

    static var installedCLI: String {
        "\(installDirectory)/\(executableName)"
    }

    static var installedDylib: String {
        "\(installDirectory)/\(dylibName)"
    }

    static var displayInstallDirectory: String {
        (installDirectory as NSString).abbreviatingWithTildeInPath
    }

    static var installedDisplayPath: String {
        (installedCLI as NSString).abbreviatingWithTildeInPath
    }

    static var bundledCLI: String? {
        bundledResource(named: "ghosttile-cli")
    }

    static var bundledDylib: String? {
        bundledResource(named: "ghosthide.dylib")
    }

    static var resolved: String {
        if installedIsCurrent { return installedCLI }
        if let bundled = bundledCLI { return bundled }
        return executableName
    }

    static var isInstalled: Bool {
        installPairExists(cli: installedCLI, dylib: installedDylib)
    }

    /// Cached `--version` check; a stale installed CLI can't parse new flags like `--accept-warnings`.
    static var installedIsCurrent: Bool {
        cachedInstalledIsCurrent
    }

    private static let cachedInstalledIsCurrent: Bool = {
        guard isInstalled else { return false }
        let installedVersion = try? AppManager.run(installedCLI, ["--version"])
        return installedVersion == BuildInfo.cliDisplayVersion
    }()

    private static func bundledResource(named name: String) -> String? {
        let path = BundledResources.resourcePath(named: name)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    private static func installPairExists(cli: String, dylib: String) -> Bool {
        FileManager.default.fileExists(atPath: cli)
            && FileManager.default.fileExists(atPath: dylib)
    }
}
