import XCTest
@testable import GhostTileCore

final class MachOEditorTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghosttile-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }

    private func compileMinimalBinary() throws -> String {
        let sourcePath = tempDir.appendingPathComponent("main.c").path
        let binaryPath = tempDir.appendingPathComponent("main").path
        try "int main(){return 0;}".write(toFile: sourcePath, atomically: true, encoding: .utf8)

        let xcrun = try ShellRunner.run("/usr/bin/xcrun", arguments: ["--find", "clang"])
        try ShellRunner.run(xcrun, arguments: [
            "-o", binaryPath, sourcePath,
            "-mmacosx-version-min=15.0",
        ])

        return binaryPath
    }

    func testCleanBinaryHasNoLoadCommand() throws {
        let binaryPath = try compileMinimalBinary()
        let has = try MachOEditor.hasGhosthideLoadCommand(in: binaryPath)
        XCTAssertFalse(has, "freshly compiled binary should not have ghosthide load command")
    }

    func testInsertLoadCommand() throws {
        let binaryPath = try compileMinimalBinary()
        let inserted = try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)
        XCTAssertTrue(inserted, "insertGhosthideLoadCommand should return true on first insert")

        let has = try MachOEditor.hasGhosthideLoadCommand(in: binaryPath)
        XCTAssertTrue(has, "binary should have ghosthide load command after insert")
    }

    func testDoubleInsertionIsIdempotent() throws {
        let binaryPath = try compileMinimalBinary()
        try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)

        let sizeBefore = try FileManager.default.attributesOfItem(atPath: binaryPath)[.size] as! UInt64
        let insertedAgain = try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)
        let sizeAfter = try FileManager.default.attributesOfItem(atPath: binaryPath)[.size] as! UInt64

        XCTAssertFalse(insertedAgain, "second insert should return false")
        XCTAssertEqual(sizeBefore, sizeAfter, "file size should not change on second insert")
    }

    func testPatchedBinaryCanBeCodesigned() throws {
        let binaryPath = try compileMinimalBinary()
        try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)

        XCTAssertNoThrow(
            try ShellRunner.run("/usr/bin/codesign", arguments: ["--force", "--sign", "-", binaryPath]),
            "codesign should succeed on patched binary"
        )
    }
}
