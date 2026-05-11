import Cocoa
import Foundation
@testable import GhostTileCore
import Testing

// Serialized: each test launches a process with the same bundle id, so NSRunningApplication
// lookup can't tolerate parallel instances.
// Enabled-if: integration path requires the prebuilt dylib (`just build`).
@Suite(
    "ShowHide integration",
    .serialized,
    .enabled(if: TestAppHelper.hasDylib, "run `just build` first to produce ghosthide.dylib")
)
final class ShowHideIntegrationTests {
    private let tempDir: TestTempDirectory
    private var testApp: TestAppHelper.BuiltApp?
    private var runningProcess: Process?

    init() throws {
        tempDir = try TestTempDirectory(prefix: "ghosttile-integration")
    }

    deinit {
        runningProcess?.terminate()
        runningProcess?.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.5)
    }

    @Test func appLaunchesWithInjectedDylib() throws {
        let app = try buildApp()
        _ = try launchTestApp(app: app, env: ["GHOSTHIDE_START_VISIBLE": "1"])

        let running = findRunningApp()
        #expect(running != nil, "test app should be running")

        // Debug dylib writes to ghosthide.log — check both temp and real home
        let logPath = tempDir.url.appendingPathComponent(".config/ghosttile/ghosthide.log").path
        let homeLogPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ghosttile/ghosthide.log").path

        let logExists = FileManager.default.fileExists(atPath: logPath)
            || FileManager.default.fileExists(atPath: homeLogPath)

        if logExists {
            let logContent = (try? String(contentsOfFile: logPath, encoding: .utf8))
                ?? (try? String(contentsOfFile: homeLogPath, encoding: .utf8))
                ?? ""
            #expect(
                logContent.contains("ghosthide_load constructor entered"),
                "debug log should show constructor was called"
            )
        }
    }

    @Test func hideNotification() throws {
        let app = try buildApp()
        _ = try launchTestApp(app: app, env: ["GHOSTHIDE_START_VISIBLE": "1"])

        _ = waitForActivationPolicy(.regular, timeout: 3)
        postNotification(action: .hide)

        let hiddenResult = waitForActivationPolicy(.accessory, timeout: 5)
        #expect(hiddenResult, "app should become accessory after hide notification")
    }

    @Test func showNotification() throws {
        let app = try buildApp()
        _ = try launchTestApp(app: app)
        let startedHidden = waitForActivationPolicy(.accessory, timeout: 5)
        #expect(startedHidden, "app should start as accessory (hidden) by default")

        postNotification(action: .show)

        let shownResult = waitForActivationPolicy(.regular, timeout: 5)
        #expect(shownResult, "app should become regular after show notification")
    }

    @Test func ghosthideDisableEnvVar() throws {
        let app = try buildApp()
        _ = try launchTestApp(app: app, env: ["GHOSTHIDE_DISABLE": "1"])

        let stayedVisible = waitForActivationPolicy(.regular, timeout: 3)
        #expect(stayedVisible, "app should stay regular with GHOSTHIDE_DISABLE=1")

        postNotification(action: .hide)
        Thread.sleep(forTimeInterval: 1.0)

        let stillVisible = findRunningApp()?.activationPolicy == .regular
        #expect(stillVisible, "app should remain regular after hide with GHOSTHIDE_DISABLE=1")
    }

    // MARK: - Helpers

    private func buildApp() throws -> TestAppHelper.BuiltApp {
        if let app = testApp { return app }
        let app = try TestAppHelper.buildTestApp(in: tempDir.url)
        testApp = app
        return app
    }

    private func launchTestApp(
        app: TestAppHelper.BuiltApp,
        env: [String: String] = [:]
    ) throws -> Process {
        let sentinelPath = tempDir.url.appendingPathComponent("sentinel-\(UUID().uuidString)").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: app.binaryPath)

        var environment = ProcessInfo.processInfo.environment
        environment["GHOSTHIDE_DEBUG"] = "1"
        environment["GHOSTTILE_TEST_SENTINEL"] = sentinelPath
        for (key, value) in env {
            environment[key] = value
        }
        process.environment = environment

        try process.run()
        runningProcess = process

        let deadline = Date().addingTimeInterval(10)
        while !FileManager.default.fileExists(atPath: sentinelPath) {
            guard Date() < deadline else {
                Issue.record("Test app did not write sentinel file within 10 seconds")
                return process
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        // Wait for ghosthide_load to run on the main queue
        Thread.sleep(forTimeInterval: 1.0)
        return process
    }

    private func findRunningApp() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: TestAppHelper.bundleID).first
    }

    private func waitForActivationPolicy(
        _ expected: NSApplication.ActivationPolicy,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let app = findRunningApp(), app.activationPolicy == expected {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    private func postNotification(action: ManagedAppNotificationAction) {
        ManagedAppNotifications.post(
            bundleId: TestAppHelper.bundleID,
            action: action
        )
    }
}
