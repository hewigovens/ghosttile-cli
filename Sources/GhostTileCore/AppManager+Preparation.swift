import Foundation

public extension AppManager {
    static func needsPreparation(_ app: AppInfo) throws -> Bool {
        try AppPreparationManager.needsPreparation(app)
    }

    static func needsSudo(_ app: AppInfo) throws -> Bool {
        try AppPreparationManager.needsSudo(app)
    }

    static func backupBinary(_ app: AppInfo) throws {
        try AppPreparationManager.backupBinary(app)
    }

    static func restoreBinary(_ bundleId: String, binaryPath: String, appPath: String) throws {
        try AppRestoreManager.restoreBinary(bundleId, binaryPath: binaryPath, appPath: appPath)
    }

    static func prepare(_ app: AppInfo) throws {
        try AppPreparationManager.prepare(app)
    }

    static func extractEntitlements(_ binaryPath: String) throws -> [String: Any] {
        try AppPreparationManager.extractEntitlements(binaryPath)
    }
}
