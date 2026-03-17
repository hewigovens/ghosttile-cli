import Foundation
import GhostTileCore

enum CLIPaths {
    static let installedCLI = "/usr/local/bin/ghosttile"
    static let installedDylib = "/usr/local/bin/ghosthide.dylib"

    static var bundledCLI: String? {
        let path = BundledResources.resourcePath(named: "ghosttile-cli")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    static var bundledDylib: String? {
        let path = BundledResources.resourcePath(named: "ghosthide.dylib")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    static var resolved: String {
        if FileManager.default.fileExists(atPath: installedCLI) { return installedCLI }
        if let bundled = bundledCLI { return bundled }
        return "ghosttile"
    }
}
