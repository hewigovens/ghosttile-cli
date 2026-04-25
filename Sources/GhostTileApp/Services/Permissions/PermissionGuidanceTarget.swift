import AppKit
import Foundation

struct PermissionGuidanceTarget {
    private static let appFileExtension = "app"
    private static let bundleDisplayNameKey = "CFBundleDisplayName"
    private static let ghostTileFallbackName = "GhostTile"
    private static let terminalBundleIdentifier = "com.apple.Terminal"
    private static let terminalFallbackName = "Terminal"
    private static let terminalFallbackPath = "/System/Applications/Utilities/Terminal.app"

    let displayName: String
    let bundleURL: URL
    let icon: NSImage

    var fileName: String {
        let name = bundleURL.lastPathComponent
        return name.isEmpty ? "\(displayName).\(Self.appFileExtension)" : name
    }

    static func ghostTile(bundle: Bundle = .main) -> PermissionGuidanceTarget {
        makeTarget(bundleURL: bundle.bundleURL, fallbackName: ghostTileFallbackName)
    }

    static func terminal() -> PermissionGuidanceTarget {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleIdentifier)
            ?? URL(fileURLWithPath: terminalFallbackPath)
        return makeTarget(bundleURL: bundleURL, fallbackName: terminalFallbackName)
    }

    private static func makeTarget(bundleURL: URL, fallbackName: String) -> PermissionGuidanceTarget {
        let bundle = Bundle(url: bundleURL)
        let displayName = bundle?.object(forInfoDictionaryKey: bundleDisplayNameKey) as? String
            ?? bundle?.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? fallbackName
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 48, height: 48)
        return PermissionGuidanceTarget(displayName: displayName, bundleURL: bundleURL, icon: icon)
    }
}
