import XCTest
@testable import GhostTileCore

final class DylibHealthTests: XCTestCase {
    private static let dylibPath = {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repoRoot.appendingPathComponent(".build/ghosthide.dylib").path
    }()

    private func dylibPathOrSkip() throws -> String {
        guard FileManager.default.fileExists(atPath: Self.dylibPath) else {
            throw XCTSkip("ghosthide.dylib not found at \(Self.dylibPath) — run `just build` first")
        }
        return Self.dylibPath
    }

    func testDylibContainsArm64() throws {
        let path = try dylibPathOrSkip()
        let output = try ShellRunner.run("/usr/bin/lipo", arguments: ["-info", path])
        XCTAssertTrue(output.contains("arm64"), "dylib should contain arm64 slice")
    }

    func testLinksCocoaFramework() throws {
        let path = try dylibPathOrSkip()
        let output = try ShellRunner.run("/usr/bin/otool", arguments: ["-L", path])
        XCTAssertTrue(output.contains("Cocoa.framework"), "dylib should link Cocoa.framework")
    }

    func testHasConstructorSymbol() throws {
        let path = try dylibPathOrSkip()
        let output = try ShellRunner.run("/usr/bin/nm", arguments: [path])
        XCTAssertTrue(
            output.contains("_ghosthide_load"),
            "dylib should contain the ghosthide_load constructor symbol"
        )
    }

    func testValidMachOStructure() throws {
        let path = try dylibPathOrSkip()
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertGreaterThanOrEqual(data.count, 4, "dylib should be at least 4 bytes")

        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let magicLE = UInt32(littleEndian: magic)
        let magicBE = UInt32(bigEndian: magic)
        let validMagics: Set<UInt32> = [0xfeedfacf, 0xfeedface, 0xcafebabe, 0xcafebabf]
        XCTAssertTrue(
            validMagics.contains(magicLE) || validMagics.contains(magicBE),
            "dylib should start with valid Mach-O magic (got 0x\(String(magicLE, radix: 16)))"
        )
    }
}
