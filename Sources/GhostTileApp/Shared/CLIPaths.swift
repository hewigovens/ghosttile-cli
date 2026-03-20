import Foundation
import GhostTileCore

enum CLIPaths {
    static let installedCLI = "/usr/local/bin/ghosttile"
    static let installedDylib = "/usr/local/bin/ghosthide.dylib"

    static var bundledCLI: String? { bundledResource(named: "ghosttile-cli") }
    static var bundledDylib: String? { bundledResource(named: "ghosthide.dylib") }

    static var resolved: String {
        if FileManager.default.fileExists(atPath: installedCLI) { return installedCLI }
        if let bundled = bundledCLI { return bundled }
        return "ghosttile"
    }

    private static func bundledResource(named name: String) -> String? {
        let path = BundledResources.resourcePath(named: name)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}
