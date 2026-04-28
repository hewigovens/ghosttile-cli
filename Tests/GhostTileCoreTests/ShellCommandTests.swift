@testable import GhostTileCore
import XCTest

final class ShellCommandTests: XCTestCase {
    func testFormatUsesReadableCommandForSafeSegments() {
        let command = ShellCommand.format(
            executable: "/Users/test/.local/bin/ghosttile",
            arguments: ["manage", "com.tencent.xinWeChat"],
            requiresSudo: true
        )

        XCTAssertEqual(
            command,
            "sudo /Users/test/.local/bin/ghosttile manage com.tencent.xinWeChat"
        )
    }

    func testFormatQuotesExecutablePathWithSpaces() {
        let command = ShellCommand.format(
            executable: "/Applications/Ghost Tile.app/Contents/MacOS/ghosttile-cli",
            arguments: ["manage", "com.tencent.xinWeChat"],
            requiresSudo: true
        )

        XCTAssertEqual(
            command,
            "sudo '/Applications/Ghost Tile.app/Contents/MacOS/ghosttile-cli' manage com.tencent.xinWeChat"
        )
    }

    func testQuoteEscapesSingleQuotes() {
        XCTAssertEqual(
            ShellCommand.quote("/tmp/O'Brien.app"),
            "'/tmp/O'\\''Brien.app'"
        )
    }
}
