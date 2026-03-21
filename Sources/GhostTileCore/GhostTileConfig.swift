import Foundation

public struct HiddenApp: Codable {
    public let name: String
    public let appPath: String
    public let binaryPath: String
    public var prepared: Bool

    public init(name: String, appPath: String, binaryPath: String, prepared: Bool) {
        self.name = name
        self.appPath = appPath
        self.binaryPath = binaryPath
        self.prepared = prepared
    }
}

public struct GhostTileConfig: Codable {
    public var hidden: [String: HiddenApp] = [:]
    public init() {}
}
