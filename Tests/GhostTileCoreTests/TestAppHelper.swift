import Foundation
@testable import GhostTileCore

enum TestAppHelper {
    static let bundleID = "dev.hewig.ghosttile.testapp"

    private static let repoRoot: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let dylibPath: String = repoRoot.appendingPathComponent(".build/ghosthide.dylib").path
    static let testAppSourcePath: String = repoRoot
        .appendingPathComponent("Tests/GhostTileCoreTests/Resources/TestApp/main.m").path

    /// True when the prebuilt dylib is available — use with `@Test(.enabled(if:))` to gate
    /// tests that depend on the dylib being built (`just build` produces it).
    static var hasDylib: Bool {
        FileManager.default.fileExists(atPath: dylibPath)
    }

    struct BuiltApp {
        let bundlePath: String
        let binaryPath: String
    }

    static func buildTestApp(in tempDir: URL) throws -> BuiltApp {
        let appDir = tempDir.appendingPathComponent("TestApp.app")
        let contentsDir = appDir.appendingPathComponent("Contents")
        let macOSDir = contentsDir.appendingPathComponent("MacOS")
        let frameworksDir = contentsDir.appendingPathComponent("Frameworks")

        for dir in [macOSDir, frameworksDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let binaryPath = macOSDir.appendingPathComponent("TestApp").path
        let clang = try ShellRunner.run("/usr/bin/xcrun", arguments: ["--find", "clang"])
        try ShellRunner.run(clang, arguments: [
            "-framework", "Cocoa",
            "-o", binaryPath,
            testAppSourcePath,
            "-mmacosx-version-min=15.0",
            "-Wl,-rpath,@executable_path/../Frameworks",
        ])

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>\(bundleID)</string>
            <key>CFBundleExecutable</key>
            <string>TestApp</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>LSUIElement</key>
            <false/>
        </dict>
        </plist>
        """
        try plist.write(
            to: contentsDir.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )

        let dylibDest = frameworksDir.appendingPathComponent("ghosthide.dylib").path
        try FileManager.default.copyItem(atPath: dylibPath, toPath: dylibDest)
        try MachOEditor.insertGhosthideLoadCommand(in: binaryPath)
        try ShellRunner.run("/usr/bin/codesign", arguments: [
            "--force", "--sign", "-", "--deep", appDir.path,
        ])

        return BuiltApp(bundlePath: appDir.path, binaryPath: binaryPath)
    }
}
