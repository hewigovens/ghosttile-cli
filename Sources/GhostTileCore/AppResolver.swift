import AppKit
import Foundation

enum AppResolver {
    static func resolve(_ query: String) throws -> AppInfo {
        if let app = try resolveBundlePath(query) {
            return app
        }

        return try resolveRunningApp(query)
    }

    static func resolveRunningApp(_ query: String) throws -> AppInfo {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil
        }

        let q = query.lowercased()

        if let app = apps.first(where: {
            guard let bundleId = $0.bundleIdentifier else { return false }
            return bundleId.lowercased() == q
        }) {
            return try info(from: app)
        }

        let matches = apps.filter {
            guard let bundleId = $0.bundleIdentifier else { return false }
            return bundleId.lowercased().contains(q)
                || ($0.localizedName?.lowercased().contains(q) ?? false)
        }

        if matches.count == 1 {
            return try info(from: matches[0])
        }

        if matches.count > 1 {
            let list = matches.map {
                "  \($0.localizedName ?? "?")  \($0.bundleIdentifier ?? "?")"
            }
            throw GhostTileError(
                "Multiple matches for '\(query)':\n\(list.joined(separator: "\n"))\nBe more specific."
            )
        }

        throw GhostTileError(
            "No running app matching '\(query)'. Run 'ghosttile list' to see running apps."
        )
    }

    static func resolveBundlePath(_ query: String) throws -> AppInfo? {
        let expanded = (query as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") || query.hasPrefix("~") else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory) else {
            throw GhostTileError("No app bundle found at '\(query)'.")
        }

        guard isDirectory.boolValue, expanded.hasSuffix(".app") else {
            throw GhostTileError("'\(query)' is not a macOS app bundle.")
        }

        return try info(fromBundleURL: URL(fileURLWithPath: expanded))
    }

    static func info(from app: NSRunningApplication) throws -> AppInfo {
        guard let bundleId = app.bundleIdentifier,
              let bundleURL = app.bundleURL,
              let bundle = Bundle(url: bundleURL)
        else {
            throw GhostTileError(
                "Could not inspect app metadata for '\(app.localizedName ?? "Unknown app")'."
            )
        }

        return try info(
            from: bundle,
            fallbackName: app.localizedName ?? bundleId,
            appPath: bundleURL.path
        )
    }

    static func info(fromBundleURL bundleURL: URL) throws -> AppInfo {
        guard let bundle = Bundle(url: bundleURL) else {
            throw GhostTileError("Could not load app bundle at '\(bundleURL.path)'.")
        }

        let fallbackName =
            bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
                ?? FileManager.default.displayName(atPath: bundleURL.path)

        return try info(from: bundle, fallbackName: fallbackName, appPath: bundleURL.path)
    }

    private static func info(
        from bundle: Bundle,
        fallbackName: String,
        appPath: String
    ) throws -> AppInfo {
        guard let bundleId = bundle.bundleIdentifier,
              let executableURL = bundle.executableURL
        else {
            throw GhostTileError("Could not inspect app metadata for '\(fallbackName)'.")
        }

        return AppInfo(
            bundleId: bundleId,
            name: fallbackName,
            appPath: appPath,
            binaryPath: executableURL.path
        )
    }
}
