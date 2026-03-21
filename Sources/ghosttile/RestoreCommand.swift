import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Restore: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove an app from the managed list and restore it."
        )
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let (bundleId, hiddenApp) = try resolveManaged(app)
            let wasRunning = isRunning(bundleId)

            if wasRunning {
                print("Quitting \(hiddenApp.name)...")
                try AppManager.quit(bundleId)
            }

            print("Restoring \(hiddenApp.name)...")
            try AppManager.restoreBinary(bundleId, binaryPath: hiddenApp.binaryPath, appPath: hiddenApp.appPath)
            try Config.removeHidden(bundleId)

            if wasRunning {
                try AppManager.launchNormal(hiddenApp.appPath)
                print("\(hiddenApp.name) restored and visible in Dock.")
            } else {
                print("\(hiddenApp.name) restored.")
            }
        }
    }
}
