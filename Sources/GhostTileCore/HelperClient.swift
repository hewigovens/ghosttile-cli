import Foundation

public extension String {
    var escapedForAppleScript: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

public enum HelperClient {
    @discardableResult
    private static func runPrivileged(_ command: String) throws -> String {
        Log.info("Running privileged: \(command)")
        let escaped = command.escapedForAppleScript
        let script = NSAppleScript(source:
            "do shell script \"\(escaped)\" with administrator privileges"
        )
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            Log.error("Privileged command failed: \(message)")
            throw GhostTileError(message)
        }
        return result?.stringValue ?? ""
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func copyFile(from source: String, to destination: String) throws {
        let command = "/bin/cp \(shellQuote(source)) \(shellQuote(destination))"
        try runPrivileged(command)
        Log.info("Privileged copy succeeded: \(source) -> \(destination)")
    }

    public static func createDirectory(atPath path: String) throws {
        let command = "/bin/mkdir -p \(shellQuote(path))"
        try runPrivileged(command)
        Log.info("Privileged mkdir succeeded: \(path)")
    }

    public static func removeFile(atPath path: String) throws {
        let command = "/bin/rm \(shellQuote(path))"
        try runPrivileged(command)
        Log.info("Privileged remove succeeded: \(path)")
    }

    // May fail on App Store apps due to responsible process check
    public static func codesign(arguments: [String]) throws {
        let args = arguments.map { shellQuote($0) }
        let command = "/usr/bin/codesign \(args.joined(separator: " "))"
        try runPrivileged(command)
        Log.info("Privileged codesign succeeded")
    }
}
