import Foundation

public enum ShellCommand {
    public static func format(
        executable: String,
        arguments: [String],
        requiresSudo: Bool = false
    ) -> String {
        var segments: [String] = []
        if requiresSudo {
            segments.append("sudo")
        }
        segments.append(executable)
        segments.append(contentsOf: arguments)
        return segments.map(quote).joined(separator: " ")
    }

    public static func quote(_ string: String) -> String {
        guard !string.isEmpty else { return "''" }
        if string.unicodeScalars.allSatisfy(isSafe) {
            return string
        }
        return "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func isSafe(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 48 ... 57, 65 ... 90, 97 ... 122, 45, 46, 47, 58, 61, 64, 95:
            true
        default:
            false
        }
    }
}
