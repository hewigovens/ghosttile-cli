import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Restore: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove an app from the managed list and restore it.")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let config = Config.load()
            let q = app.lowercased()

            let match = config.hidden.first {
                $0.key.lowercased().contains(q)
                    || $0.value.name.lowercased().contains(q)
            }

            guard let (bundleId, hiddenApp) = match else {
                throw GhostTileError(
                    "'\(app)' is not managed. Run 'ghosttile status' to see managed apps.")
            }

            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            if !running.isEmpty {
                print("Quitting \(hiddenApp.name)...")
                try AppManager.quit(bundleId)
            }

            print("Restoring \(hiddenApp.name)...")
            try AppManager.restoreBinary(bundleId, binaryPath: hiddenApp.binaryPath, appPath: hiddenApp.appPath)
            try Config.removeHidden(bundleId)
            if !running.isEmpty {
                try AppManager.launchNormal(hiddenApp.appPath)
                print("\(hiddenApp.name) restored and visible in Dock.")
            } else {
                print("\(hiddenApp.name) restored.")
            }
        }
    }
}
