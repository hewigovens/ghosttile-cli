import Foundation
@testable import GhostTileCore

/// A minimal mock `.app` bundle for tests: a compiled stub Mach-O inside a real bundle layout.
struct AppMock {
    let bundleId: String
    let appPath: String
    let binaryPath: String

    static func make(
        in directory: URL,
        bundleId: String = "dev.hewig.ghosttile.mock.\(UUID().uuidString)",
        executableName: String = "Mock",
        shortVersion: String = "1.0",
        build: String = "10"
    ) throws -> AppMock {
        let appURL = directory.appendingPathComponent("\(bundleId).app")
        let contentsURL = appURL.appendingPathComponent("Contents")
        let macOSURL = contentsURL.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        let binaryURL = macOSURL.appendingPathComponent(executableName)
        try compileStubBinary(at: binaryURL.path)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>\(bundleId)</string>
            <key>CFBundleExecutable</key>
            <string>\(executableName)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>\(shortVersion)</string>
            <key>CFBundleVersion</key>
            <string>\(build)</string>
        </dict>
        </plist>
        """
        try plist.write(to: contentsURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        return AppMock(bundleId: bundleId, appPath: appURL.path, binaryPath: binaryURL.path)
    }

    /// Compile a bare minimal Mach-O executable at `binaryPath` (no bundle).
    static func compileStubBinary(at binaryPath: String) throws {
        let sourcePath = "\(binaryPath)-\(UUID().uuidString).c"
        defer { try? FileManager.default.removeItem(atPath: sourcePath) }
        try "int main(){return 0;}".write(toFile: sourcePath, atomically: true, encoding: .utf8)

        let clang = try ShellRunner.run("/usr/bin/xcrun", arguments: ["--find", "clang"])
        try ShellRunner.run(clang, arguments: [
            "-o", binaryPath, sourcePath,
            "-mmacosx-version-min=15.0",
        ])
    }
}
