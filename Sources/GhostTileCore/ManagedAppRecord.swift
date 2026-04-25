import AppKit
import Foundation

public struct ManagedAppRecord: Identifiable, Encodable, Sendable {
    public let bundleId: String
    public let name: String
    public let appPath: String
    public let binaryPath: String
    public let managed: Bool
    public let running: Bool
    public let hiddenFromDock: Bool
    public let pid: pid_t?
    public let isSIPProtected: Bool
    public let categoryIdentifier: String?

    public var id: String {
        bundleId
    }

    public init(
        bundleId: String,
        name: String,
        appPath: String,
        binaryPath: String,
        managed: Bool,
        running: Bool,
        hiddenFromDock: Bool,
        pid: pid_t?,
        isSIPProtected: Bool,
        categoryIdentifier: String?
    ) {
        self.bundleId = bundleId
        self.name = name
        self.appPath = appPath
        self.binaryPath = binaryPath
        self.managed = managed
        self.running = running
        self.hiddenFromDock = hiddenFromDock
        self.pid = pid
        self.isSIPProtected = isSIPProtected
        self.categoryIdentifier = categoryIdentifier
    }
}
