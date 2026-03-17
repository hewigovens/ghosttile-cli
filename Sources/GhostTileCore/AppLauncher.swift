import AppKit
import Foundation

enum AppLauncher {
    static func quit(_ bundleId: String) throws {
        Log.info("Quitting \(bundleId)")
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in apps {
            app.terminate()
        }

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

    static func launchHidden(_ app: AppInfo) throws {
        Log.info("Launching \(app.name) hidden")
        try launchBinary(at: app.binaryPath, environment: ProcessInfo.processInfo.environment)
    }

    static func launchManagedVisible(_ app: AppInfo) throws {
        Log.info("Launching \(app.name) visible")
        var environment = ProcessInfo.processInfo.environment
        environment["GHOSTHIDE_START_VISIBLE"] = "1"
        try launchBinary(at: app.binaryPath, environment: environment)
    }

    static func launchNormal(_ appPath: String) throws {
        Log.info("Launching \(appPath) normally")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appPath]
        try process.run()
        process.waitUntilExit()
    }

    static func isSIPProtected(_ path: String) -> Bool {
        path.hasPrefix("/System") || path.hasPrefix("/usr")
    }

    static func isAppleFirstParty(_ path: String) -> Bool {
        if isSIPProtected(path) {
            return true
        }

        let output = (try? ShellRunner.run(
            "/usr/bin/codesign",
            arguments: ["-dvvv", path],
            captureStderr: true
        )) ?? ""
        return output.contains("Authority=Software Signing")
    }

    private static func launchBinary(at path: String, environment: [String: String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        try process.run()
    }
}
