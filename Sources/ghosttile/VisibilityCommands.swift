import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Hide: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Hide a managed app from Dock (send hide notification).")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            try sendVisibilityNotification(app, action: .hide)
        }
    }

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show a managed app in Dock (send show notification).")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            try sendVisibilityNotification(app, action: .show)
        }
    }
}
