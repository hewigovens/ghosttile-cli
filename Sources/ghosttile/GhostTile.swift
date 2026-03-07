import ArgumentParser
import GhostTileCore

@main
struct GhostTile: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ghosttile",
        abstract: "Hide apps from Dock and Cmd+Tab.",
        version: "2.0.0",
        subcommands: [List.self, Hide.self, Show.self, Status.self, Focus.self, Setup.self],
        defaultSubcommand: List.self
    )
}
