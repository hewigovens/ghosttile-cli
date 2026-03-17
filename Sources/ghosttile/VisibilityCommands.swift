import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Hide: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Hide a managed app from Dock (send hide notification).")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let (bundleId, hiddenApp) = try resolveManaged(app)

            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            guard !running.isEmpty else {
                print("\(hiddenApp.name) is not running.")
                return
            }

            ManagedAppNotifications.post(bundleId: bundleId, action: .hide)
            print("\(hiddenApp.name) hidden from Dock.")
        }
    }

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show a managed app in Dock (send show notification).")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let (bundleId, hiddenApp) = try resolveManaged(app)

            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            guard !running.isEmpty else {
                print("\(hiddenApp.name) is not running.")
                return
            }

            ManagedAppNotifications.post(bundleId: bundleId, action: .show)
            print("\(hiddenApp.name) shown in Dock.")
        }
    }
}
