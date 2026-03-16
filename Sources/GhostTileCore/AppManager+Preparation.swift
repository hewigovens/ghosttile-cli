import Foundation

public extension AppManager {
    static func needsPreparation(_ app: AppInfo) throws -> Bool {
        Log.debug("Checking if \(app.name) (\(app.bundleId)) needs preparation")
        let output = try run("/usr/bin/codesign", ["-dvvv", app.binaryPath], captureStderr: true)
        let usesRuntime = output.contains("runtime")
        let helperInstalled = FileManager.default.fileExists(atPath: Dylib.bundleInstallPath(forAppPath: app.appPath))
        let hasLoadCommand = try MachOEditor.hasGhosthideLoadCommand(in: app.binaryPath)

        let entitlements = try extractEntitlements(app.binaryPath)
        let hasDyldEntitlement =
            entitlements["com.apple.security.cs.allow-dyld-environment-variables"] != nil
        let hasLibraryValidationEntitlement =
            entitlements["com.apple.security.cs.disable-library-validation"] != nil

        let needs = !helperInstalled
            || !hasLoadCommand
            || (usesRuntime && (!hasDyldEntitlement || !hasLibraryValidationEntitlement))
        Log.debug("\(app.name) needs preparation: \(needs)")
        return needs
    }

    static func needsSudo(_ app: AppInfo) throws -> Bool {
        guard try needsPreparation(app) else { return false }
        return !FileManager.default.isWritableFile(atPath: app.binaryPath)
    }

    static func backupBinary(_ app: AppInfo) throws {
        let dir = backupPath(for: app.bundleId)
        let dest = "\(dir)/binary"
        if FileManager.default.fileExists(atPath: dest) {
            Log.info("Backup already exists for \(app.name), skipping")
            return
        }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: app.binaryPath, toPath: dest)
        Log.info("Backed up binary for \(app.name) to \(dest)")
    }

    static func restoreBinary(_ bundleId: String, binaryPath: String, appPath: String) throws {
        let src = "\(backupPath(for: bundleId))/binary"
        guard FileManager.default.fileExists(atPath: src) else {
            Log.info("No backup found for \(bundleId), skipping restore")
            return
        }

        Log.info("Restoring original binary for \(bundleId)")

        do {
            try FileManager.default.removeItem(atPath: binaryPath)
            try FileManager.default.copyItem(atPath: src, toPath: binaryPath)
            Log.info("Restored binary directly for \(bundleId)")
        } catch {
            Log.info("Direct restore failed, trying via admin privileges")
            try HelperClient.copyFile(from: src, to: binaryPath)
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
            try run("/usr/bin/codesign", ["--force", "--sign", "-", appPath])
        } catch {
            Log.info("Bundle re-sign after restore failed (non-fatal): \(error)")
        }

        try? FileManager.default.removeItem(atPath: backupPath(for: bundleId))
        Log.info("Removed backup for \(bundleId)")
    }

    static func prepare(_ app: AppInfo) throws {
        Log.info("Preparing \(app.name) (\(app.bundleId)) at \(app.appPath)")

        try backupBinary(app)

        let helperSourcePath = try Dylib.ensureDylib()
        let helperInstallPath = Dylib.bundleInstallPath(forAppPath: app.appPath)
        try installHelper(from: helperSourcePath, to: helperInstallPath)

        var entitlements = try extractEntitlements(app.binaryPath)
        entitlements["com.apple.security.cs.allow-dyld-environment-variables"] = true
        entitlements["com.apple.security.cs.disable-library-validation"] = true

        let entPath = NSTemporaryDirectory() + "ghosttile_ent.plist"
        let data = try PropertyListSerialization.data(
            fromPropertyList: entitlements, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: entPath))
        defer { try? FileManager.default.removeItem(atPath: entPath) }

        let tempBinary = NSTemporaryDirectory() + "ghosttile_work_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tempBinary) }

        try FileManager.default.copyItem(atPath: app.binaryPath, toPath: tempBinary)
        try stripSignatureIfPresent(at: tempBinary)
        _ = try MachOEditor.insertGhosthideLoadCommand(in: tempBinary)
        try run(
            "/usr/bin/codesign",
            ["--force", "--sign", "-", "--entitlements", entPath, tempBinary]
        )
        try installPreparedBinary(from: tempBinary, to: app.binaryPath)
        Log.info("Prepared binary for \(app.name)")

        do {
            try run("/usr/bin/codesign", ["--force", "--sign", "-", helperInstallPath])
        } catch {
            try HelperClient.codesign(arguments: ["--force", "--sign", "-", helperInstallPath])
        }

        do {
            try run(
                "/usr/bin/codesign",
                ["--force", "--sign", "-", "--preserve-metadata=entitlements", app.appPath]
            )
            Log.info("Re-signed bundle for \(app.name)")
        } catch {
            Log.info("Direct bundle codesign failed for \(app.name), trying via admin privileges")
            do {
                try HelperClient.codesign(arguments: [
                    "--force", "--sign", "-", "--preserve-metadata=entitlements", app.appPath
                ])
                Log.info("Re-signed bundle for \(app.name) via admin")
            } catch {
                Log.error("Failed to re-sign bundle for \(app.name): \(error)")
                throw GhostTileError(
                    "\(app.name) requires a manual step. Run in Terminal: sudo ghosttile hide \(app.bundleId)"
                )
            }
        }
    }

    static func extractEntitlements(_ binaryPath: String) throws -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-d", "--entitlements", "-", binaryPath]
        let pipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        else { return [:] }
        return plist
    }
}

extension AppManager {
    static func backupPath(for bundleId: String) -> String {
        "\(Config.backupDir)/\(bundleId)"
    }

    static func stripSignatureIfPresent(at binaryPath: String) throws {
        do {
            try run("/usr/bin/codesign", ["--remove-signature", binaryPath])
        } catch {
            Log.info("codesign --remove-signature skipped for \(binaryPath): \(error)")
        }
    }

    static func installPreparedBinary(from source: String, to destination: String) throws {
        do {
            try FileManager.default.removeItem(atPath: destination)
            try FileManager.default.copyItem(atPath: source, toPath: destination)
        } catch {
            Log.info("Direct install of prepared binary failed, trying via admin privileges")
            try HelperClient.copyFile(from: source, to: destination)
        }
    }

    static func installHelper(from source: String, to destination: String) throws {
        let directory = (destination as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            try HelperClient.createDirectory(atPath: directory)
        }

        if FileManager.default.fileExists(atPath: destination) {
            do {
                try FileManager.default.removeItem(atPath: destination)
            } catch {
                try? HelperClient.removeFile(atPath: destination)
            }
        }

        do {
            try FileManager.default.copyItem(atPath: source, toPath: destination)
        } catch {
            try HelperClient.copyFile(from: source, to: destination)
        }
    }
}
