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
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil
        }

        let q = query.lowercased()

        if let app = apps.first(where: { $0.bundleIdentifier!.lowercased() == q }) {
            return info(from: app)
        }

        let matches = apps.filter {
            $0.bundleIdentifier!.lowercased().contains(q)
                || ($0.localizedName?.lowercased().contains(q) ?? false)
        }

        if matches.count == 1 { return info(from: matches[0]) }

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

    public static func info(from app: NSRunningApplication) -> AppInfo {
        let bundle = Bundle(url: app.bundleURL!)!
        return AppInfo(
            bundleId: app.bundleIdentifier!,
            name: app.localizedName ?? app.bundleIdentifier!,
            appPath: app.bundleURL!.path,
            binaryPath: bundle.executableURL!.path
        )
    }

    // MARK: - Code Signing

    public static func needsPreparation(_ app: AppInfo) throws -> Bool {
        Log.debug("Checking if \(app.name) (\(app.bundleId)) needs preparation")
        let output = try run(
            "/usr/bin/codesign", ["-dvvv", app.binaryPath], captureStderr: true)
        guard output.contains("runtime") else {
            Log.debug("\(app.name) has no hardened runtime, no preparation needed")
            return false
        }

        let entitlements = try extractEntitlements(app.binaryPath)
        let needs = entitlements["com.apple.security.cs.allow-dyld-environment-variables"] == nil
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

        var entitlements = try extractEntitlements(app.binaryPath)
        entitlements["com.apple.security.cs.allow-dyld-environment-variables"] = true
        entitlements["com.apple.security.cs.disable-library-validation"] = true

        let entPath = NSTemporaryDirectory() + "ghosttile_ent.plist"
        let data = try PropertyListSerialization.data(
            fromPropertyList: entitlements, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: entPath))
        defer { try? FileManager.default.removeItem(atPath: entPath) }

        // Re-sign binary with DYLD entitlements
        do {
            try run(
                "/usr/bin/codesign",
                ["--force", "--sign", "-", "--entitlements", entPath, app.binaryPath])
            Log.info("Re-signed binary for \(app.name)")
        } catch {
            Log.info("Direct codesign failed for \(app.name), trying copy-sign-copy approach")
            try codesignViaCopy(
                binaryPath: app.binaryPath,
                extraArgs: ["--entitlements", entPath],
                label: app.name
            )
        }

        // Re-sign the bundle
        do {
            try run("/usr/bin/codesign", ["--force", "--sign", "-", app.appPath])
            Log.info("Re-signed bundle for \(app.name)")
        } catch {
            Log.info("Direct bundle codesign failed for \(app.name), trying via admin privileges")
            do {
                try HelperClient.codesign(arguments: [
                    "--force", "--sign", "-", app.appPath
                ])
                Log.info("Re-signed bundle for \(app.name) via admin")
            } catch {
                Log.error("Failed to re-sign bundle for \(app.name): \(error)")
                throw GhostTileError(
                    "\(app.name) has hardened runtime and cannot be re-signed from the GUI. Install the CLI in Settings, then run: sudo ghosttile hide \(app.bundleId)"
                )
            }
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
        process.arguments = ["-d", "--entitlements", ":-", binaryPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
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

    public static func launchHidden(_ app: AppInfo, dylibPath: String) throws {
        Log.info("Launching \(app.name) hidden with dylib: \(dylibPath)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: app.binaryPath)
        var env = ProcessInfo.processInfo.environment
        env["DYLD_INSERT_LIBRARIES"] = dylibPath
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
