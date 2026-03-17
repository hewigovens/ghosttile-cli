import Foundation

enum AppRestoreManager {
    static func restoreBinary(_ bundleId: String, binaryPath: String, appPath: String) throws {
        let source = "\(backupPath(for: bundleId))/binary"
        guard FileManager.default.fileExists(atPath: source) else {
            Log.info("No backup found for \(bundleId), skipping restore")
            return
        }

        Log.info("Restoring original binary for \(bundleId)")

        do {
            try FileManager.default.removeItem(atPath: binaryPath)
            try FileManager.default.copyItem(atPath: source, toPath: binaryPath)
            Log.info("Restored binary directly for \(bundleId)")
        } catch {
            Log.info("Direct restore failed, trying via admin privileges")
            try HelperClient.copyFile(from: source, to: binaryPath)
            Log.info("Restored binary via admin for \(bundleId)")
        }

        let helperPath = Dylib.bundleInstallPath(forAppPath: appPath)
        if FileManager.default.fileExists(atPath: helperPath) {
            do {
                try FileManager.default.removeItem(atPath: helperPath)
            } catch {
                try? HelperClient.removeFile(atPath: helperPath)
            }
        }

        do {
            try ShellRunner.run("/usr/bin/codesign", arguments: ["--force", "--sign", "-", appPath])
        } catch {
            Log.info("Bundle re-sign after restore failed (non-fatal): \(error)")
        }

        try? FileManager.default.removeItem(atPath: backupPath(for: bundleId))
        Log.info("Removed backup for \(bundleId)")
    }

    private static func backupPath(for bundleId: String) -> String {
        "\(Config.backupDir)/\(bundleId)"
    }
}
