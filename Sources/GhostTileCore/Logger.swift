import Foundation
import os.log

public enum Log {
    private static let osLog = OSLog(subsystem: "dev.hewig.ghosttile", category: "general")
    private static let logFileURL: URL = {
        let home: String
        if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"],
           let pw = getpwnam(sudoUser) {
            home = String(cString: pw.pointee.pw_dir)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser.path
        }
        let dir = URL(fileURLWithPath: home).appendingPathComponent(".config/ghosttile")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ghosttile.log")
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    public static func info(_ message: String) {
        os_log(.info, log: osLog, "%{public}@", message)
        write("INFO", message)
    }

    public static func error(_ message: String) {
        os_log(.error, log: osLog, "%{public}@", message)
        write("ERROR", message)
    }

    public static func debug(_ message: String) {
        os_log(.debug, log: osLog, "%{public}@", message)
        write("DEBUG", message)
    }

    private static func write(_ level: String, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    public static var logPath: String { logFileURL.path }
}
