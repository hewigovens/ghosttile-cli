import XCTest
@testable import GhostTileCore

final class ConfigTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghosttile-config-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        Config.configDirOverride = tempDir.path
    }

    override func tearDown() {
        Config.configDirOverride = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }

    func testLoadReturnsDefaultWhenNoFile() {
        let config = Config.load()
        XCTAssertTrue(config.hidden.isEmpty, "default config should have no hidden apps")
    }

    func testSaveAndLoadRoundTrip() throws {
        var config = GhostTileConfig()
        config.hidden["com.example.app"] = HiddenApp(
            name: "Example",
            appPath: "/Applications/Example.app",
            binaryPath: "/Applications/Example.app/Contents/MacOS/Example",
            prepared: true
        )

        try Config.save(config)
        let loaded = Config.load()

        XCTAssertEqual(loaded.hidden.count, 1)
        XCTAssertEqual(loaded.hidden["com.example.app"]?.name, "Example")
        XCTAssertEqual(loaded.hidden["com.example.app"]?.appPath, "/Applications/Example.app")
        XCTAssertEqual(loaded.hidden["com.example.app"]?.prepared, true)
    }

    func testAddHidden() throws {
        try Config.addHidden("com.test.app", app: HiddenApp(
            name: "Test",
            appPath: "/Applications/Test.app",
            binaryPath: "/Applications/Test.app/Contents/MacOS/Test",
            prepared: false
        ))

        let config = Config.load()
        XCTAssertNotNil(config.hidden["com.test.app"])
        XCTAssertEqual(config.hidden["com.test.app"]?.name, "Test")
    }

    func testRemoveHidden() throws {
        try Config.addHidden("com.test.app", app: HiddenApp(
            name: "Test",
            appPath: "/Applications/Test.app",
            binaryPath: "/Applications/Test.app/Contents/MacOS/Test",
            prepared: false
        ))

        try Config.removeHidden("com.test.app")
        let config = Config.load()
        XCTAssertNil(config.hidden["com.test.app"])
    }
}
