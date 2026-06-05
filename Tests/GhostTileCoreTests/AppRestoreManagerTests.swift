import Foundation
@testable import GhostTileCore
import Testing

@Suite("AppRestoreManager", .serialized)
final class AppRestoreManagerTests {
    private let tempDir: TestTempDirectory

    init() throws {
        ConfigTestIsolation.semaphore.wait()
        do {
            tempDir = try TestTempDirectory(prefix: "ghosttile-restore-tests")
            Config.configDirOverride = tempDir.url.appendingPathComponent("config").path
        } catch {
            ConfigTestIsolation.semaphore.signal()
            throw error
        }
    }

    deinit {
        Config.configDirOverride = nil
        ConfigTestIsolation.semaphore.signal()
    }

    @Test func restoreForgetsWhenCurrentBinaryIsNotPatched() throws {
        let app = try makeApp()
        let cleanData = try Data(contentsOf: URL(fileURLWithPath: app.binaryPath))
        try writeBackup(bundleId: app.bundleId, sourcePath: app.binaryPath)

        try AppRestoreManager.restoreBinary(
            app.bundleId,
            binaryPath: app.binaryPath,
            appPath: app.appPath
        )

        #expect(try Data(contentsOf: URL(fileURLWithPath: app.binaryPath)) == cleanData)
        #expect(!FileManager.default.fileExists(atPath: FileOperations.backupPath(for: app.bundleId)))
    }

    @Test func restoreRemovesOrphanedDylibWhenBinaryIsNotPatched() throws {
        let app = try makeApp()
        try writeBackup(bundleId: app.bundleId, sourcePath: app.binaryPath)
        let dylibPath = Dylib.bundleInstallPath(forAppPath: app.appPath)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: dylibPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("stub".utf8).write(to: URL(fileURLWithPath: dylibPath))

        try AppRestoreManager.restoreBinary(
            app.bundleId,
            binaryPath: app.binaryPath,
            appPath: app.appPath
        )

        #expect(!FileManager.default.fileExists(atPath: dylibPath))
        #expect(!FileManager.default.fileExists(atPath: FileOperations.backupPath(for: app.bundleId)))
    }

    @Test func restoreReplacesPatchedBinary() throws {
        let app = try makeApp()
        try writeBackup(bundleId: app.bundleId, sourcePath: app.binaryPath)
        try MachOEditor.insertGhosthideLoadCommand(in: app.binaryPath)
        #expect(try MachOEditor.hasGhosthideLoadCommand(in: app.binaryPath))

        try AppRestoreManager.restoreBinary(
            app.bundleId,
            binaryPath: app.binaryPath,
            appPath: app.appPath
        )

        #expect(try !MachOEditor.hasGhosthideLoadCommand(in: app.binaryPath))
        #expect(!FileManager.default.fileExists(atPath: FileOperations.backupPath(for: app.bundleId)))
    }

    private func makeApp() throws -> AppMock {
        try AppMock.make(in: tempDir.url)
    }

    private func writeBackup(bundleId: String, sourcePath: String) throws {
        let backupURL = URL(fileURLWithPath: FileOperations.backupPath(for: bundleId))
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            atPath: sourcePath,
            toPath: backupURL.appendingPathComponent("binary").path
        )
    }
}
