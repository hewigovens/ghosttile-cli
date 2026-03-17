import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Focus: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Bring a hidden app to front.")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let q = app.lowercased()
            let running = NSWorkspace.shared.runningApplications.filter {
                ($0.bundleIdentifier?.lowercased().contains(q) ?? false)
                    || ($0.localizedName?.lowercased().contains(q) ?? false)
            }

            guard let target = running.first else {
                throw GhostTileError("No running app matching '\(app)'")
            }

            target.activate()
            print("Activated \(target.localizedName ?? target.bundleIdentifier ?? "app").")
        }
    }
}
