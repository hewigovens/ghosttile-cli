import AppKit

public extension AppManager {
    static func quit(_ bundleId: String) throws {
        try AppLauncher.quit(bundleId)
    }

    static func launchHidden(_ app: AppInfo) throws {
        try AppLauncher.launchHidden(app)
    }

    static func launchManagedVisible(_ app: AppInfo) throws {
        try AppLauncher.launchManagedVisible(app)
    }

    static func launchNormal(_ appPath: String) throws {
        try AppLauncher.launchNormal(appPath)
    }

    static func isSIPProtected(_ path: String) -> Bool {
        AppLauncher.isSIPProtected(path)
    }

    static func isAppleFirstParty(_ path: String) -> Bool {
        AppLauncher.isAppleFirstParty(path)
    }
}
