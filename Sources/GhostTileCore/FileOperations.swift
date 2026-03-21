import Foundation

enum FileOperations {
    static func replaceFile(from source: String, to destination: String) throws {
        do {
            if FileManager.default.fileExists(atPath: destination) {
                try FileManager.default.removeItem(atPath: destination)
            }
            try FileManager.default.copyItem(atPath: source, toPath: destination)
        } catch {
            Log.info("Direct file replace failed for \(destination), trying via admin")
            try HelperClient.copyFile(from: source, to: destination)
        }
    }

    static func removeFile(atPath path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            try HelperClient.removeFile(atPath: path)
        }
    }

    static func createDirectory(atPath path: String) throws {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch {
            try HelperClient.createDirectory(atPath: path)
        }
    }

    static func codesign(arguments: [String]) throws {
        do {
            try ShellRunner.run("/usr/bin/codesign", arguments: arguments)
        } catch {
            Log.info("Direct codesign failed, trying via admin")
            try HelperClient.codesign(arguments: arguments)
        }
    }

    static func backupPath(for bundleId: String) -> String {
        "\(Config.backupDir)/\(bundleId)"
    }
}
