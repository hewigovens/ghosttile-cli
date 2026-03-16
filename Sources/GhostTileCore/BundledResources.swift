import Foundation

public enum BundledResources {
    public static var executableURL: URL {
        Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
    }

    public static var resourcesDirectoryURL: URL {
        executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
    }

    public static func resourceURL(named name: String) -> URL {
        resourcesDirectoryURL.appendingPathComponent(name)
    }

    public static func resourcePath(named name: String) -> String {
        resourceURL(named: name).path
    }
}
