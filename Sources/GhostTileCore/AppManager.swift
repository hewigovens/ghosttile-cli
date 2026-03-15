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
    public static func resolve(_ query: String) throws -> AppInfo {
        if let app = try resolveBundlePath(query) {
            return app
        }

        return try resolveRunningApp(query)
    }

    public static func resolveRunningApp(_ query: String) throws -> AppInfo {
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

        if matches.count == 1 { return try info(from: matches[0]) }

        if matches.count > 1 {
            let list = matches.map {
                "  \($0.localizedName ?? "?")  \($0.bundleIdentifier ?? "?")"
            }
            throw GhostTileError(
                "Multiple matches for '\(query)':\n\(list.joined(separator: "\n"))\nBe more specific."
            )
        }

        throw GhostTileError(
            "No running app matching '\(query)'. Run 'ghosttile list' to see running apps.")
    }

    public static func resolveBundlePath(_ query: String) throws -> AppInfo? {
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

    public static func info(from app: NSRunningApplication) throws -> AppInfo {
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

    public static func info(fromBundleURL bundleURL: URL) throws -> AppInfo {
        guard let bundle = Bundle(url: bundleURL) else {
            throw GhostTileError("Could not load app bundle at '\(bundleURL.path)'.")
        }

        let fallbackName = bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? FileManager.default.displayName(atPath: bundleURL.path)

        return try info(from: bundle, fallbackName: fallbackName, appPath: bundleURL.path)
    }

    private static func info(from bundle: Bundle, fallbackName: String, appPath: String) throws -> AppInfo {
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

    // MARK: - Code Signing

    public static func needsPreparation(_ app: AppInfo) throws -> Bool {
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

    /// Check if a hardened app's binary is not writable by the current user (needs sudo)
    public static func needsSudo(_ app: AppInfo) throws -> Bool {
        guard try needsPreparation(app) else { return false }
        return !FileManager.default.isWritableFile(atPath: app.binaryPath)
    }

    // MARK: - Backup & Restore

    private static func backupPath(for bundleId: String) -> String {
        "\(Config.backupDir)/\(bundleId)"
    }

    /// Back up the original binary before re-signing
    public static func backupBinary(_ app: AppInfo) throws {
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

    /// Restore the original binary from backup
    public static func restoreBinary(_ bundleId: String, binaryPath: String, appPath: String) throws {
        let src = "\(backupPath(for: bundleId))/binary"
        guard FileManager.default.fileExists(atPath: src) else {
            Log.info("No backup found for \(bundleId), skipping restore")
            return
        }

        Log.info("Restoring original binary for \(bundleId)")

        // Try direct copy first, fall back to admin cp
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

        // Re-sign the bundle to match the restored binary
        do {
            try run("/usr/bin/codesign", ["--force", "--sign", "-", appPath])
        } catch {
            // Best effort — bundle codesign failure is non-fatal for restore
            Log.info("Bundle re-sign after restore failed (non-fatal): \(error)")
        }

        // Clean up backup
        try? FileManager.default.removeItem(atPath: backupPath(for: bundleId))
        Log.info("Removed backup for \(bundleId)")
    }

    // MARK: - Prepare (re-sign)

    public static func prepare(_ app: AppInfo) throws {
        Log.info("Preparing \(app.name) (\(app.bundleId)) at \(app.appPath)")

        // Back up original binary before modifying
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

        // Re-sign the bundle
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

    private static func stripSignatureIfPresent(at binaryPath: String) throws {
        do {
            try run("/usr/bin/codesign", ["--remove-signature", binaryPath])
        } catch {
            // Unsigned binaries or already stripped binaries are fine here.
            Log.info("codesign --remove-signature skipped for \(binaryPath): \(error)")
        }
    }

    private static func installPreparedBinary(from source: String, to destination: String) throws {
        do {
            try FileManager.default.removeItem(atPath: destination)
            try FileManager.default.copyItem(atPath: source, toPath: destination)
        } catch {
            Log.info("Direct install of prepared binary failed, trying via admin privileges")
            try HelperClient.copyFile(from: source, to: destination)
        }
    }

    private static func installHelper(from source: String, to destination: String) throws {
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

    /// Codesign a protected binary by copying it to a temp location, signing the copy,
    /// then using admin privileges to copy it back. Works around macOS "responsible process"
    /// restrictions that block codesign on App Store binaries from GUI apps.
    private static func codesignViaCopy(
        binaryPath: String, extraArgs: [String], label: String
    ) throws {
        let tempBinary = NSTemporaryDirectory() + "ghosttile_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tempBinary) }

        // 1. Copy binary to temp (readable by all)
        try FileManager.default.copyItem(atPath: binaryPath, toPath: tempBinary)
        Log.info("Copied binary to \(tempBinary)")

        // 2. Codesign the temp copy (user-owned, no protection)
        let args = ["--force", "--sign", "-"] + extraArgs + [tempBinary]
        try run("/usr/bin/codesign", args)
        Log.info("Signed temp copy for \(label)")

        // 3. Copy signed binary back via admin privileges
        try HelperClient.copyFile(from: tempBinary, to: binaryPath)
        Log.info("Copied signed binary back for \(label)")
    }

    public static func extractEntitlements(_ binaryPath: String) throws -> [String: Any] {
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

    // MARK: - Process Management

    public static func quit(_ bundleId: String) throws {
        Log.info("Quitting \(bundleId)")
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in apps { app.terminate() }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty {
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId) {
            app.forceTerminate()
        }
        Thread.sleep(forTimeInterval: 0.5)
    }

    public static func launchHidden(_ app: AppInfo) throws {
        Log.info("Launching \(app.name) hidden")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: app.binaryPath)
        process.environment = ProcessInfo.processInfo.environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        try process.run()
    }

    public static func launchManagedVisible(_ app: AppInfo) throws {
        Log.info("Launching \(app.name) visible")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: app.binaryPath)
        var env = ProcessInfo.processInfo.environment
        env["GHOSTHIDE_START_VISIBLE"] = "1"
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        try process.run()
    }

    public static func launchNormal(_ appPath: String) throws {
        Log.info("Launching \(appPath) normally")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appPath]
        try process.run()
        process.waitUntilExit()
    }

    public static func isSIPProtected(_ path: String) -> Bool {
        path.hasPrefix("/System") || path.hasPrefix("/usr")
    }

    /// Check if the app is an Apple first-party system app (not re-signable)
    public static func isAppleFirstParty(_ path: String) -> Bool {
        if isSIPProtected(path) { return true }
        let output = (try? run(
            "/usr/bin/codesign", ["-dvvv", path], captureStderr: true)) ?? ""
        // "Software Signing" is Apple's own first-party signing identity
        // "Apple Mac OS Application Signing" is for ALL App Store apps (including third-party)
        return output.contains("Authority=Software Signing")
    }

    // MARK: - Shell

    @discardableResult
    public static func run(
        _ executable: String, _ args: [String], captureStderr: Bool = false
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = captureStderr ? pipe : FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8) ?? ""
            throw GhostTileError(
                "\(URL(fileURLWithPath: executable).lastPathComponent) failed: \(output)")
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
