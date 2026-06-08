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

    /// Cached byte comparison vs the bundled CLI/dylib, so any change is detected without a version bump.
    static var installedIsCurrent: Bool {
        cachedInstalledIsCurrent
    }

    private static let cachedInstalledIsCurrent: Bool = {
        guard isInstalled,
              let cli = bundledCLI,
              let dylib = bundledDylib
        else { return false }
        return filesAreIdentical(installedCLI, cli) && filesAreIdentical(installedDylib, dylib)
    }()

    private static func filesAreIdentical(_ lhs: String, _ rhs: String) -> Bool {
        let fileManager = FileManager.default
        guard let lhsSize = try? fileManager.attributesOfItem(atPath: lhs)[.size] as? Int,
              let rhsSize = try? fileManager.attributesOfItem(atPath: rhs)[.size] as? Int,
              lhsSize == rhsSize
        else { return false }
        guard let lhsData = try? Data(contentsOf: URL(fileURLWithPath: lhs), options: .mappedIfSafe),
              let rhsData = try? Data(contentsOf: URL(fileURLWithPath: rhs), options: .mappedIfSafe)
        else { return false }
        return lhsData == rhsData
    }

    private static func bundledResource(named name: String) -> String? {
        let path = BundledResources.resourcePath(named: name)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    private static func installPairExists(cli: String, dylib: String) -> Bool {
        FileManager.default.fileExists(atPath: cli)
            && FileManager.default.fileExists(atPath: dylib)
    }
}
