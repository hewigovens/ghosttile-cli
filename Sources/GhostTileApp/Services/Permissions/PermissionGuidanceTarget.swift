import AppKit
import Foundation

struct PermissionGuidanceTarget {
    let displayName: String
    let bundleURL: URL
    let icon: NSImage

    var fileName: String {
        let name = bundleURL.lastPathComponent
        return name.isEmpty ? "\(displayName).app" : name
    }

    static func ghostTile(bundle: Bundle = .main) -> PermissionGuidanceTarget {
        makeTarget(bundleURL: bundle.bundleURL, fallbackName: "GhostTile")
    }

    static func terminal() -> PermissionGuidanceTarget {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
            ?? URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        return makeTarget(bundleURL: bundleURL, fallbackName: "Terminal")
    }

    private static func makeTarget(bundleURL: URL, fallbackName: String) -> PermissionGuidanceTarget {
        let bundle = Bundle(url: bundleURL)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? fallbackName
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 48, height: 48)
        return PermissionGuidanceTarget(displayName: displayName, bundleURL: bundleURL, icon: icon)
    }
}
