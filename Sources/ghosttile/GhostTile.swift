import ArgumentParser
import GhostTileCore

@main
struct GhostTile: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ghosttile",
        abstract: "Hide apps from Dock and Cmd+Tab.",
        version: BuildInfo.displayVersion,
        subcommands: [Manage.self, Restore.self, Hide.self, Show.self, List.self, Status.self, Focus.self]
    )
}
