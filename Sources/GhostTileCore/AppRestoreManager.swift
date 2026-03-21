import Foundation

enum AppRestoreManager {
    static func restoreBinary(_ bundleId: String, binaryPath: String, appPath: String) throws {
        let source = "\(FileOperations.backupPath(for: bundleId))/binary"
        guard FileManager.default.fileExists(atPath: source) else {
            Log.info("No backup found for \(bundleId), skipping restore")
            return
        }

        Log.info("Restoring original binary for \(bundleId)")

        try FileOperations.replaceFile(from: source, to: binaryPath)
        Log.info("Restored binary for \(bundleId)")

        try? FileOperations.removeFile(atPath: Dylib.bundleInstallPath(forAppPath: appPath))

        do {
            try ShellRunner.run("/usr/bin/codesign", arguments: ["--force", "--sign", "-", appPath])
        } catch {
            Log.info("Bundle re-sign after restore failed (non-fatal): \(error)")
        }

        try? FileManager.default.removeItem(atPath: FileOperations.backupPath(for: bundleId))
        Log.info("Removed backup for \(bundleId)")
    }
}
