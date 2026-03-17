import Foundation

enum ShellRunner {
    @discardableResult
    static func run(
        _ executable: String,
        arguments: [String],
        captureStderr: Bool = false
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = captureStderr ? pipe : FileHandle.nullDevice

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8) ?? ""
            throw GhostTileError(
                "\(URL(fileURLWithPath: executable).lastPathComponent) failed: \(output)"
            )
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
