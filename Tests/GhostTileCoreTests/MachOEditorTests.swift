import Foundation
@testable import GhostTileCore
import Testing

@Suite("MachOEditor")
final class MachOEditorTests {
    private let tempDir: TestTempDirectory

    init() throws {
        tempDir = try TestTempDirectory(prefix: "ghosttile-macho-tests")
    }

    @Test func cleanBinaryHasNoLoadCommand() throws {
        let binaryPath = try compileMinimalBinary()
        let has = try MachOEditor.hasGhosthideLoadCommand(in: binaryPath)
        #expect(!has, "freshly compiled binary should not have ghosthide load command")
    }

    @Test func insertLoadCommand() throws {
        let binaryPath = try compileMinimalBinary()
        let inserted = try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)
        #expect(inserted, "insertGhosthideLoadCommand should return true on first insert")

        let has = try MachOEditor.hasGhosthideLoadCommand(in: binaryPath)
        #expect(has, "binary should have ghosthide load command after insert")
    }

    @Test func doubleInsertionIsIdempotent() throws {
        let binaryPath = try compileMinimalBinary()
        try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)

        let sizeBefore = try #require(
            FileManager.default.attributesOfItem(atPath: binaryPath)[.size] as? UInt64
        )
        let insertedAgain = try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)
        let sizeAfter = try #require(
            FileManager.default.attributesOfItem(atPath: binaryPath)[.size] as? UInt64
        )

        #expect(!insertedAgain, "second insert should return false")
        #expect(sizeBefore == sizeAfter, "file size should not change on second insert")
    }

    @Test func patchedBinaryCanBeCodesigned() throws {
        let binaryPath = try compileMinimalBinary()
        try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)
        // If codesign fails the test throws and is recorded as a failure automatically.
        try ShellRunner.run("/usr/bin/codesign", arguments: ["--force", "--sign", "-", binaryPath])
    }

    @Test func ensureFrameworksRpathInsertsWhenMissing() throws {
        let binaryPath = try compileMinimalBinary()
        #expect(try !otoolHasRpath(binaryPath, MachOEditor.frameworksRpath))

        let inserted = try MachOEditor.ensureFrameworksRpath(in: binaryPath)
        #expect(inserted, "ensureFrameworksRpath should return true when no rpath exists")
        #expect(try otoolHasRpath(binaryPath, MachOEditor.frameworksRpath))
    }

    @Test func ensureFrameworksRpathIsIdempotent() throws {
        let binaryPath = try compileMinimalBinary()
        try MachOEditor.ensureFrameworksRpath(in: binaryPath)

        let sizeBefore = try #require(
            FileManager.default.attributesOfItem(atPath: binaryPath)[.size] as? UInt64
        )
        let insertedAgain = try MachOEditor.ensureFrameworksRpath(in: binaryPath)
        let sizeAfter = try #require(
            FileManager.default.attributesOfItem(atPath: binaryPath)[.size] as? UInt64
        )

        #expect(!insertedAgain, "second call should be a no-op")
        #expect(sizeBefore == sizeAfter)
    }

    // MARK: - Helpers

    private func compileMinimalBinary() throws -> String {
        let sourcePath = tempDir.url.appendingPathComponent("main.c").path
        let binaryPath = tempDir.url.appendingPathComponent("main").path
        try "int main(){return 0;}".write(toFile: sourcePath, atomically: true, encoding: .utf8)

        let xcrun = try ShellRunner.run("/usr/bin/xcrun", arguments: ["--find", "clang"])
        try ShellRunner.run(xcrun, arguments: [
            "-o", binaryPath, sourcePath,
            "-mmacosx-version-min=15.0",
        ])

        return binaryPath
    }

    private func otoolHasRpath(_ binaryPath: String, _ rpath: String) throws -> Bool {
        let output = try ShellRunner.run("/usr/bin/otool", arguments: ["-l", binaryPath])
        // otool prints a stanza per LC_RPATH; we look for the explicit path token.
        return output.contains("path \(rpath)")
    }
}
