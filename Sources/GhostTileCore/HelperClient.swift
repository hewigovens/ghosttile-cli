import Foundation

public enum HelperClient {
    /// Run a shell command as root via AppleScript admin prompt
    @discardableResult
    private static func runPrivileged(_ command: String) throws -> String {
        Log.info("Running privileged: \(command)")
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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

    /// Copy a file as root via admin privileges
    public static func copyFile(from source: String, to destination: String) throws {
        let command = "/bin/cp \(shellQuote(source)) \(shellQuote(destination))"
        try runPrivileged(command)
        Log.info("Privileged copy succeeded: \(source) -> \(destination)")
    }

    /// Create a directory as root via admin privileges
    public static func createDirectory(atPath path: String) throws {
        let command = "/bin/mkdir -p \(shellQuote(path))"
        try runPrivileged(command)
        Log.info("Privileged mkdir succeeded: \(path)")
    }

    /// Remove a file as root via admin privileges
    public static func removeFile(atPath path: String) throws {
        let command = "/bin/rm \(shellQuote(path))"
        try runPrivileged(command)
        Log.info("Privileged remove succeeded: \(path)")
    }

    /// Codesign via admin privileges (may fail on App Store apps due to responsible process)
    public static func codesign(arguments: [String]) throws {
        let args = arguments.map { shellQuote($0) }
        let command = "/usr/bin/codesign \(args.joined(separator: " "))"
        try runPrivileged(command)
        Log.info("Privileged codesign succeeded")
    }
}
