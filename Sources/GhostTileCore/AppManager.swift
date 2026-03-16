import AppKit
import Foundation

public struct AppInfo {
    public let bundleId: String
    public let name: String
    public let appPath: String
    public let binaryPath: String

    public init(bundleId: String, name: String, appPath: String, binaryPath: String) {
        self.bundleId = bundleId
        self.name = name
        self.appPath = appPath
        self.binaryPath = binaryPath
    }
}

public enum AppManager {
}
