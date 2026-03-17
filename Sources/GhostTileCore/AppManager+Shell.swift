import Foundation

public extension AppManager {
    @discardableResult
    static func run(
        _ executable: String, _ args: [String], captureStderr: Bool = false
    ) throws -> String {
        try ShellRunner.run(executable, arguments: args, captureStderr: captureStderr)
    }
}
