import Foundation

/// Creates a unique temp directory and removes it when the instance is deallocated.
/// Hold as a stored property on a test class so cleanup runs in the class's deinit.
final class TestTempDirectory {
    let url: URL

    init(prefix: String = "ghosttile-tests") throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    var path: String {
        url.path
    }
}

/// Serializes config-mutating suites; a semaphore (not NSLock) since init/deinit may run on separate threads.
enum ConfigTestIsolation {
    static let semaphore = DispatchSemaphore(value: 1)
}
