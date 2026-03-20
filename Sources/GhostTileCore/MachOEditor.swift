import Foundation

enum MachOEditor {
    static let ghosthideInstallName = "@rpath/ghosthide.dylib"

    private static let fatMagic: UInt32 = 0xCAFE_BABE
    private static let fatMagic64: UInt32 = 0xCAFE_BABF
    private static let mhMagic: UInt32 = 0xFEED_FACE
    private static let mhMagic64: UInt32 = 0xFEED_FACF
    private static let lcSegment: UInt32 = 0x1
    private static let lcSymtab: UInt32 = 0x2
    private static let lcLoadDylib: UInt32 = 0xC
    private static let lcLoadWeakDylib: UInt32 = 0x18 | 0x8000_0000
    private static let lcSegment64: UInt32 = 0x19
    private static let lcBuildVersion: UInt32 = 0x32
    private static let reservedCodeSignatureCommandSpace = 16

    struct Slice {
        let offset: Int
        let size: Int
    }

    static func hasGhosthideLoadCommand(in binaryPath: String) throws -> Bool {
        let data = try Data(contentsOf: URL(fileURLWithPath: binaryPath))
        return try slices(in: data).contains { try sliceHasGhosthideLoadCommand(data, slice: $0) }
    }

    @discardableResult
    static func insertGhosthideLoadCommand(in binaryPath: String) throws -> Bool {
        var data = try Data(contentsOf: URL(fileURLWithPath: binaryPath))
        var modified = false

        for slice in try slices(in: data) {
            if try insertGhosthideLoadCommand(into: &data, slice: slice) {
                modified = true
            }
        }

        if modified {
            try data.write(to: URL(fileURLWithPath: binaryPath))
        }

        return modified
    }

    private static func slices(in data: Data) throws -> [Slice] {
        guard data.count >= 4 else {
            throw GhostTileError("File is too small to be a Mach-O binary.")
        }

        let magic = readUInt32BE(data, at: 0)
        if magic == fatMagic || magic == fatMagic64 {
            let nfatArch = Int(readUInt32BE(data, at: 4))
            let is64 = magic == fatMagic64
            let archSize = is64 ? 32 : 20
            let base = is64 ? 8 : 8
            return (0 ..< nfatArch).map { index in
                let archOffset = base + (index * archSize)
                let sliceOffset: Int
                let sliceSize: Int
                if is64 {
                    sliceOffset = Int(readUInt64BE(data, at: archOffset + 8))
                    sliceSize = Int(readUInt64BE(data, at: archOffset + 16))
                } else {
                    sliceOffset = Int(readUInt32BE(data, at: archOffset + 8))
                    sliceSize = Int(readUInt32BE(data, at: archOffset + 12))
                }
                return Slice(offset: sliceOffset, size: sliceSize)
            }
        }

        let fileMagic = readUInt32LE(data, at: 0)
        guard fileMagic == self.mhMagic || fileMagic == mhMagic64 else {
            throw GhostTileError("Unsupported Mach-O binary format.")
        }
        return [Slice(offset: 0, size: data.count)]
    }

    private static func sliceHasGhosthideLoadCommand(_ data: Data, slice: Slice) throws -> Bool {
        let header = try parseHeader(data, slice: slice)
        var cursor = header.commandsOffset
        for _ in 0 ..< header.ncmds {
            let cmd = readUInt32LE(data, at: cursor)
            let cmdsize = Int(readUInt32LE(data, at: cursor + 4))
            if cmd == lcLoadDylib || cmd == lcLoadWeakDylib {
                let nameOffset = Int(readUInt32LE(data, at: cursor + 8))
                let name = readCString(data, at: cursor + nameOffset, maxLength: cmdsize - nameOffset)
                if name == ghosthideInstallName {
                    return true
                }
            }
            cursor += cmdsize
        }
        return false
    }

    private static func insertGhosthideLoadCommand(into data: inout Data, slice: Slice) throws -> Bool {
        if try sliceHasGhosthideLoadCommand(data, slice: slice) {
            return false
        }

        let command = makeDylibCommand(path: ghosthideInstallName)
        var header = try parseHeader(data, slice: slice)
        var availableSpace = try availableHeaderSpace(data, slice: slice, header: header)

        for removableCommand in [lcBuildVersion] {
            if availableSpace >= command.count + reservedCodeSignatureCommandSpace {
                break
            }
            if removeLoadCommand(&data, slice: slice, header: header, matching: removableCommand) {
                header = try parseHeader(data, slice: slice)
                availableSpace = try availableHeaderSpace(data, slice: slice, header: header)
            }
        }

        guard availableSpace >= command.count + reservedCodeSignatureCommandSpace else {
            throw GhostTileError(
                "Not enough Mach-O header space to add ghosthide.dylib to \(sliceDescription(slice, header: header))."
            )
        }

        let insertOffset = header.commandsOffset + header.sizeofcmds
        data.replaceSubrange(insertOffset ..< (insertOffset + command.count), with: command)
        writeUInt32LE(&data, at: slice.offset + 16, value: UInt32(header.ncmds + 1))
        writeUInt32LE(&data, at: slice.offset + 20, value: UInt32(header.sizeofcmds + command.count))
        return true
    }

    @discardableResult
    private static func removeLoadCommand(
        _ data: inout Data,
        slice: Slice,
        header: Header,
        matching commandToRemove: UInt32
    ) -> Bool {
        var cursor = header.commandsOffset
        let commandsEnd = header.commandsOffset + header.sizeofcmds

        for _ in 0 ..< header.ncmds {
            let cmd = readUInt32LE(data, at: cursor)
            let cmdsize = Int(readUInt32LE(data, at: cursor + 4))
            if cmd == commandToRemove {
                let commandEnd = cursor + cmdsize
                let tail = Data(data[commandEnd ..< commandsEnd])
                data.replaceSubrange(cursor ..< (cursor + tail.count), with: tail)
                data.replaceSubrange((commandsEnd - cmdsize) ..< commandsEnd, with: Data(repeating: 0, count: cmdsize))
                writeUInt32LE(&data, at: slice.offset + 16, value: UInt32(header.ncmds - 1))
                writeUInt32LE(&data, at: slice.offset + 20, value: UInt32(header.sizeofcmds - cmdsize))
                return true
            }
            cursor += cmdsize
        }

        return false
    }

    private static func availableHeaderSpace(_ data: Data, slice _: Slice, header: Header) throws -> Int {
        var minOffset = Int.max
        var cursor = header.commandsOffset

        for _ in 0 ..< header.ncmds {
            let cmd = readUInt32LE(data, at: cursor)
            let cmdsize = Int(readUInt32LE(data, at: cursor + 4))

            switch cmd {
            case lcSegment:
                let fileoff = Int(readUInt32LE(data, at: cursor + 32))
                let nsects = Int(readUInt32LE(data, at: cursor + 48))
                if fileoff > 0 { minOffset = min(minOffset, fileoff) }
                var sectionOffset = cursor + 56
                for _ in 0 ..< nsects {
                    let sectionFileOffset = Int(readUInt32LE(data, at: sectionOffset + 40))
                    if sectionFileOffset > 0 { minOffset = min(minOffset, sectionFileOffset) }
                    sectionOffset += 68
                }
            case lcSegment64:
                let fileoff = Int(readUInt64LE(data, at: cursor + 40))
                let nsects = Int(readUInt32LE(data, at: cursor + 64))
                if fileoff > 0 { minOffset = min(minOffset, fileoff) }
                var sectionOffset = cursor + 72
                for _ in 0 ..< nsects {
                    let sectionFileOffset = Int(readUInt32LE(data, at: sectionOffset + 48))
                    if sectionFileOffset > 0 { minOffset = min(minOffset, sectionFileOffset) }
                    sectionOffset += 80
                }
            case lcSymtab:
                let symoff = Int(readUInt32LE(data, at: cursor + 8))
                let stroff = Int(readUInt32LE(data, at: cursor + 16))
                if symoff > 0 { minOffset = min(minOffset, symoff) }
                if stroff > 0 { minOffset = min(minOffset, stroff) }
            default:
                break
            }

            cursor += cmdsize
        }

        guard minOffset != Int.max else {
            throw GhostTileError("Could not determine available Mach-O header space.")
        }

        return minOffset - (header.headerSize + header.sizeofcmds)
    }

    private static func makeDylibCommand(path: String) -> Data {
        let pathBytes = Array(path.utf8) + [0]
        let cmdsize = align(24 + pathBytes.count, to: 8)
        var command = Data(count: cmdsize)
        writeUInt32LE(&command, at: 0, value: lcLoadDylib)
        writeUInt32LE(&command, at: 4, value: UInt32(cmdsize))
        writeUInt32LE(&command, at: 8, value: 24)
        writeUInt32LE(&command, at: 12, value: 0)
        writeUInt32LE(&command, at: 16, value: 0)
        writeUInt32LE(&command, at: 20, value: 0)
        command.replaceSubrange(24 ..< (24 + pathBytes.count), with: pathBytes)
        return command
    }

    private struct Header {
        let headerSize: Int
        let commandsOffset: Int
        let ncmds: Int
        let sizeofcmds: Int
        let is64: Bool
    }

    private static func parseHeader(_ data: Data, slice: Slice) throws -> Header {
        let magic = readUInt32LE(data, at: slice.offset)
        let is64: Bool
        switch magic {
        case mhMagic:
            is64 = false
        case mhMagic64:
            is64 = true
        default:
            throw GhostTileError("Unsupported Mach-O slice format.")
        }

        let headerSize = is64 ? 32 : 28
        return Header(
            headerSize: headerSize,
            commandsOffset: slice.offset + headerSize,
            ncmds: Int(readUInt32LE(data, at: slice.offset + 16)),
            sizeofcmds: Int(readUInt32LE(data, at: slice.offset + 20)),
            is64: is64
        )
    }

    private static func sliceDescription(_ slice: Slice, header: Header) -> String {
        header.is64 ? "64-bit slice at 0x\(String(slice.offset, radix: 16))" : "32-bit slice at 0x\(String(slice.offset, radix: 16))"
    }

    private static func align(_ value: Int, to alignment: Int) -> Int {
        ((value + alignment - 1) / alignment) * alignment
    }

    private static func readCString(_ data: Data, at offset: Int, maxLength: Int) -> String {
        guard maxLength > 0 else { return "" }
        let upperBound = min(offset + maxLength, data.count)
        let bytes = data[offset ..< upperBound]
        let nulIndex = bytes.firstIndex(of: 0) ?? upperBound
        return String(decoding: data[offset ..< nulIndex], as: UTF8.self)
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { rawBuffer in
            UInt32(littleEndian: rawBuffer.load(fromByteOffset: offset, as: UInt32.self))
        }
    }

    private static func readUInt64LE(_ data: Data, at offset: Int) -> UInt64 {
        data.withUnsafeBytes { rawBuffer in
            UInt64(littleEndian: rawBuffer.load(fromByteOffset: offset, as: UInt64.self))
        }
    }

    private static func readUInt32BE(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { rawBuffer in
            UInt32(bigEndian: rawBuffer.load(fromByteOffset: offset, as: UInt32.self))
        }
    }

    private static func readUInt64BE(_ data: Data, at offset: Int) -> UInt64 {
        data.withUnsafeBytes { rawBuffer in
            UInt64(bigEndian: rawBuffer.load(fromByteOffset: offset, as: UInt64.self))
        }
    }

    private static func writeUInt32LE(_ data: inout Data, at offset: Int, value: UInt32) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            data.replaceSubrange(offset ..< (offset + 4), with: bytes)
        }
    }
}
