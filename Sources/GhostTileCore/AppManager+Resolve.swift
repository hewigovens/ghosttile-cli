import AppKit
import Foundation

public extension AppManager {
    static func resolve(_ query: String) throws -> AppInfo {
        try AppResolver.resolve(query)
    }

    static func resolveRunningApp(_ query: String) throws -> AppInfo {
        try AppResolver.resolveRunningApp(query)
    }

    static func resolveBundlePath(_ query: String) throws -> AppInfo? {
        try AppResolver.resolveBundlePath(query)
    }

    static func info(from app: NSRunningApplication) throws -> AppInfo {
        try AppResolver.info(from: app)
    }

    static func info(fromBundleURL bundleURL: URL) throws -> AppInfo {
        try AppResolver.info(fromBundleURL: bundleURL)
    }
}
