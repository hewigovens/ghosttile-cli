import Foundation

enum AppPreparationManager {
    static func needsPreparation(_ app: AppInfo) throws -> Bool {
        Log.debug("Checking if \(app.name) (\(app.bundleId)) needs preparation")
        let output = try ShellRunner.run(
            "/usr/bin/codesign",
            arguments: ["-dvvv", app.binaryPath],
            captureStderr: true
        )
        let usesRuntime = output.contains("runtime")
        let helperInstalled = FileManager.default.fileExists(
            atPath: Dylib.bundleInstallPath(forAppPath: app.appPath)
        )
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
        let directory = FileOperations.backupPath(for: app.bundleId)
        let destination = "\(directory)/binary"

        if FileManager.default.fileExists(atPath: destination) {
            Log.info("Backup already exists for \(app.name), skipping")
            return
        }

        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: app.binaryPath, toPath: destination)
        Log.info("Backed up binary for \(app.name) to \(destination)")
    }

    static func prepare(_ app: AppInfo, cliPath: String = "ghosttile") throws {
        Log.info("Preparing \(app.name) (\(app.bundleId)) at \(app.appPath)")

        try backupBinary(app)

        let helperSourcePath = try Dylib.ensureDylib()
        let helperInstallPath = Dylib.bundleInstallPath(forAppPath: app.appPath)
        let helperDir = (helperInstallPath as NSString).deletingLastPathComponent
        try FileOperations.createDirectory(atPath: helperDir)
        try FileOperations.replaceFile(from: helperSourcePath, to: helperInstallPath)

        var entitlements = try extractEntitlements(app.binaryPath)
        entitlements["com.apple.security.cs.allow-dyld-environment-variables"] = true
        entitlements["com.apple.security.cs.disable-library-validation"] = true

        let entitlementsPath = NSTemporaryDirectory() + "ghosttile_ent.plist"
        let data = try PropertyListSerialization.data(
            fromPropertyList: entitlements,
            format: .xml,
            options: 0
        )
        try data.write(to: URL(fileURLWithPath: entitlementsPath))
        defer { try? FileManager.default.removeItem(atPath: entitlementsPath) }

        let temporaryBinary = NSTemporaryDirectory() + "ghosttile_work_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: temporaryBinary) }

        try FileManager.default.copyItem(atPath: app.binaryPath, toPath: temporaryBinary)
        try stripSignatureIfPresent(at: temporaryBinary)
        _ = try MachOEditor.insertGhosthideLoadCommand(in: temporaryBinary)
        try ShellRunner.run(
            "/usr/bin/codesign",
            arguments: ["--force", "--sign", "-", "--entitlements", entitlementsPath, temporaryBinary]
        )
        try FileOperations.replaceFile(from: temporaryBinary, to: app.binaryPath)
        Log.info("Prepared binary for \(app.name)")

        try FileOperations.codesign(arguments: ["--force", "--sign", "-", helperInstallPath])

        do {
            try FileOperations.codesign(arguments: [
                "--force", "--sign", "-", "--preserve-metadata=entitlements", app.appPath,
            ])
            Log.info("Re-signed bundle for \(app.name)")
        } catch {
            Log.error("Failed to re-sign bundle for \(app.name): \(error)")
            throw GhostTileError(
                "\(app.name) requires a manual step. Run in Terminal: \(ShellCommand.format(executable: cliPath, arguments: ["manage", app.bundleId], requiresSudo: true))"
            )
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
        else {
            return [:]
        }

        return plist
    }

    private static func stripSignatureIfPresent(at binaryPath: String) throws {
        do {
            try ShellRunner.run(
                "/usr/bin/codesign",
                arguments: ["--remove-signature", binaryPath]
            )
        } catch {
            Log.info("codesign --remove-signature skipped for \(binaryPath): \(error)")
        }
    }
}
