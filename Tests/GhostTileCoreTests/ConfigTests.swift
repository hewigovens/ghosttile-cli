import Foundation
@testable import GhostTileCore
import Testing

@Suite("Config", .serialized) // Config.configDirOverride is global state — must not race.
final class ConfigTests {
    private let tempDir: TestTempDirectory

    init() throws {
        tempDir = try TestTempDirectory(prefix: "ghosttile-config-tests")
        Config.configDirOverride = tempDir.path
    }

    deinit {
        Config.configDirOverride = nil
    }

    @Test func loadReturnsDefaultWhenNoFile() {
        let config = Config.load()
        #expect(config.hidden.isEmpty, "default config should have no hidden apps")
    }

    @Test func saveAndLoadRoundTrip() throws {
        var config = GhostTileConfig()
        config.hidden["com.example.app"] = HiddenApp(
            name: "Example",
            appPath: "/Applications/Example.app",
            binaryPath: "/Applications/Example.app/Contents/MacOS/Example",
            prepared: true
        )

        try Config.save(config)
        let loaded = Config.load()

        #expect(loaded.hidden.count == 1)
        #expect(loaded.hidden["com.example.app"]?.name == "Example")
        #expect(loaded.hidden["com.example.app"]?.appPath == "/Applications/Example.app")
        #expect(loaded.hidden["com.example.app"]?.prepared == true)
    }

    @Test func addHidden() throws {
        try Config.addHidden("com.test.app", app: HiddenApp(
            name: "Test",
            appPath: "/Applications/Test.app",
            binaryPath: "/Applications/Test.app/Contents/MacOS/Test",
            prepared: false
        ))

        let config = Config.load()
        #expect(config.hidden["com.test.app"] != nil)
        #expect(config.hidden["com.test.app"]?.name == "Test")
    }

    @Test func removeHidden() throws {
        try Config.addHidden("com.test.app", app: HiddenApp(
            name: "Test",
            appPath: "/Applications/Test.app",
            binaryPath: "/Applications/Test.app/Contents/MacOS/Test",
            prepared: false
        ))

        try Config.removeHidden("com.test.app")
        let config = Config.load()
        #expect(config.hidden["com.test.app"] == nil)
    }
}
