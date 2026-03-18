import Foundation

public enum Config {
    public static var backupDir: String { "\(configDir)/backups" }

    public static var configDir: String {
        // When running via sudo, use the real user's home instead of /var/root
        let home: String
        if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"],
           let pw = getpwnam(sudoUser) {
            home = String(cString: pw.pointee.pw_dir)
        } else if let envHome = getenv("HOME") {
            home = String(cString: envHome)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser.path
        }
        return "\(home)/.config/ghosttile"
    }

    public static var configPath: String { "\(configDir)/config.json" }

    public static func load() -> GhostTileConfig {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(GhostTileConfig.self, from: data)
        else { return GhostTileConfig() }
        return config
    }

    public static func save(_ config: GhostTileConfig) throws {
        try FileManager.default.createDirectory(
            atPath: configDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: configPath))
    }

    public static func addHidden(_ bundleId: String, app: HiddenApp) throws {
        var config = load()
        config.hidden[bundleId] = app
        try save(config)
    }

    public static func removeHidden(_ bundleId: String) throws {
        var config = load()
        config.hidden.removeValue(forKey: bundleId)
        try save(config)
    }
}
