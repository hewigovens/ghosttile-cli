import Foundation
@testable import GhostTileCore
import Testing

@Suite("Dylib health", .enabled(if: TestAppHelper.hasDylib, "run `just build` first to produce ghosthide.dylib"))
struct DylibHealthTests {
    private var dylibPath: String {
        TestAppHelper.dylibPath
    }

    @Test func dylibContainsArm64() throws {
        let output = try ShellRunner.run("/usr/bin/lipo", arguments: ["-info", dylibPath])
        #expect(output.contains("arm64"), "dylib should contain arm64 slice")
    }

    @Test func linksCocoaFramework() throws {
        let output = try ShellRunner.run("/usr/bin/otool", arguments: ["-L", dylibPath])
        #expect(output.contains("Cocoa.framework"), "dylib should link Cocoa.framework")
    }

    @Test func hasConstructorSymbol() throws {
        let output = try ShellRunner.run("/usr/bin/nm", arguments: [dylibPath])
        #expect(
            output.contains("_ghosthide_load"),
            "dylib should contain the ghosthide_load constructor symbol"
        )
    }

    @Test func validMachOStructure() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: dylibPath))
        #expect(data.count >= 4, "dylib should be at least 4 bytes")

        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let magicLE = UInt32(littleEndian: magic)
        let magicBE = UInt32(bigEndian: magic)
        let validMagics: Set<UInt32> = [0xFEED_FACF, 0xFEED_FACE, 0xCAFE_BABE, 0xCAFE_BABF]
        #expect(
            validMagics.contains(magicLE) || validMagics.contains(magicBE),
            "dylib should start with valid Mach-O magic (got 0x\(String(magicLE, radix: 16)))"
        )
    }
}
