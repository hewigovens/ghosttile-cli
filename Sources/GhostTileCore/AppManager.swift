import AppKit
import Foundation

public struct AppInfo {
    public let bundleId: String
    public let name: String
    public let appPath: String
    public let binaryPath: String

    public init(bundleId: String, name: String, appPath: String, binaryPath: String) {
        self.bundleId = bundleId
        self.name = name
        self.appPath = appPath
        self.binaryPath = binaryPath
    }
}

public enum AppManager {
    /// Resolution
    public static func resolve(_ query: String) throws -> AppInfo {
        try AppResolver.resolve(query)
    }

    public static func resolveRunningApp(_ query: String) throws -> AppInfo {
        try AppResolver.resolveRunningApp(query)
    }

    public static func resolveBundlePath(_ query: String) throws -> AppInfo? {
        try AppResolver.resolveBundlePath(query)
    }

    public static func info(from app: NSRunningApplication) throws -> AppInfo {
        try AppResolver.info(from: app)
    }

    public static func info(fromBundleURL bundleURL: URL) throws -> AppInfo {
        try AppResolver
            .info(fromBundleURL: bundleURL)
    }

    /// Preparation
    public static func needsPreparation(_ app: AppInfo) throws -> Bool {
        try AppPreparationManager
            .needsPreparation(app)
    }

    public static func needsSudo(_ app: AppInfo) throws -> Bool {
        try AppPreparationManager.needsSudo(app)
    }

    public static func prepare(_ app: AppInfo, cliPath: String = "ghosttile") throws {
        try AppPreparationManager.prepare(app, cliPath: cliPath)
    }

    public static func extractEntitlements(_ binaryPath: String) throws -> [String: Any] {
        try AppPreparationManager
            .extractEntitlements(binaryPath)
    }

    /// Restore
    public static func restoreBinary(_ bundleId: String, binaryPath: String, appPath: String) throws {
        try AppRestoreManager.restoreBinary(bundleId, binaryPath: binaryPath, appPath: appPath)
    }

    /// Running app lookup
    public static func runningApps(_ bundleId: String) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    }

    public static func isRunning(_ bundleId: String) -> Bool {
        !runningApps(bundleId).isEmpty
    }

    /// Process
    public static func quit(_ bundleId: String) throws {
        try AppLauncher.quit(bundleId)
    }

    public static func launchHidden(_ app: AppInfo) throws {
        try AppLauncher.launchHidden(app)
    }

    public static func launchManagedVisible(_ app: AppInfo) throws {
        try AppLauncher.launchManagedVisible(app)
    }

    public static func launchNormal(_ appPath: String) throws {
        try AppLauncher.launchNormal(appPath)
    }

    public static func isSIPProtected(_ path: String) -> Bool {
        AppLauncher.isSIPProtected(path)
    }

    public static func isAppleFirstParty(_ path: String) -> Bool {
        AppLauncher.isAppleFirstParty(path)
    }

    /// Shell
    @discardableResult
    public static func run(_ executable: String, _ args: [String], captureStderr: Bool = false) throws -> String {
        try ShellRunner.run(executable, arguments: args, captureStderr: captureStderr)
    }
}
