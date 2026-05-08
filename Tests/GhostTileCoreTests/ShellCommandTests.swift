@testable import GhostTileCore
import Testing

@Suite("ShellCommand")
struct ShellCommandTests {
    @Test func formatUsesReadableCommandForSafeSegments() {
        let command = ShellCommand.format(
            executable: "/Users/test/.local/bin/ghosttile",
            arguments: ["manage", "com.tencent.xinWeChat"],
            requiresSudo: true
        )
        #expect(command == "sudo /Users/test/.local/bin/ghosttile manage com.tencent.xinWeChat")
    }

    @Test func formatQuotesExecutablePathWithSpaces() {
        let command = ShellCommand.format(
            executable: "/Applications/Ghost Tile.app/Contents/MacOS/ghosttile-cli",
            arguments: ["manage", "com.tencent.xinWeChat"],
            requiresSudo: true
        )
        #expect(
            command == "sudo '/Applications/Ghost Tile.app/Contents/MacOS/ghosttile-cli' manage com.tencent.xinWeChat"
        )
    }

    @Test func quoteEscapesSingleQuotes() {
        #expect(ShellCommand.quote("/tmp/O'Brien.app") == "'/tmp/O'\\''Brien.app'")
    }
}
