import Darwin
import Foundation
import GhostTileCore

enum CLIEnvironment {
    static var loginShell: String {
        guard let passwd = getpwuid(getuid()),
              let shell = passwd.pointee.pw_shell,
              let value = String(validatingUTF8: shell),
              !value.isEmpty
        else {
            return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        }

        return value
    }

    static func directoryIsInPATH(_ directory: String) -> Bool {
        let path = loginShellPATH() ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        let target = normalizedPath(directory)

        return path.split(separator: ":").contains { entry in
            normalizedPath(String(entry)) == target
        }
    }

    static func pathHint(for directory: String) -> String {
        let shell = loginShell
        let shellPath = shellLiteralPath(for: directory)

        if shell.hasSuffix("fish") {
            return "Add to ~/.config/fish/config.fish:\nfish_add_path \(shellPath)"
        }

        let rcFile = shell.hasSuffix("zsh") ? "~/.zshrc" : "~/.bashrc"
        return "Add to \(rcFile):\nexport PATH=\"\(shellPath):$PATH\""
    }

    private static func loginShellPATH() -> String? {
        let shell = loginShell
        let command = shell.hasSuffix("fish") ? "string join : -- $PATH" : "printf %s \"$PATH\""
        return try? AppManager.run(shell, ["-l", "-c", command])
    }

    private static func normalizedPath(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).standardizingPath
    }

    private static func shellLiteralPath(for directory: String) -> String {
        let homeDirectory = NSHomeDirectory()
        guard directory.hasPrefix(homeDirectory) else {
            return directory
        }

        return "$HOME" + directory.dropFirst(homeDirectory.count)
    }
}
