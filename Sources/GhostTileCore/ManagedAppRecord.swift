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
    public let requiresReAdd: Bool
    public let version: AppVersion?

    public var id: String {
        bundleId
    }

    /// Single source of truth for a managed app's presented state and its labels (CLI, status bar, UI).
    public enum DisplayState: Equatable {
        case requiresReAdd
        case running(pid: pid_t?, hiddenFromDock: Bool)
        case notRunning

        /// Compact status label for cards and pills.
        public var label: String {
            switch self {
            case .requiresReAdd: "Updated"
            case let .running(_, hiddenFromDock): hiddenFromDock ? "Hidden" : "Visible"
            case .notRunning: "Not Running"
            }
        }

        /// Verbose status label for menus.
        public var detailedLabel: String {
            switch self {
            case .requiresReAdd: "Updated - Re-add Required"
            case let .running(_, hiddenFromDock): hiddenFromDock ? "Running Hidden" : "Running Visible"
            case .notRunning: "Not Running"
            }
        }

        /// Lowercase status text for CLI output.
        public var cliStatus: String {
            switch self {
            case .requiresReAdd: "updated, re-add required"
            case let .running(pid, hiddenFromDock):
                "\(pid.map { "pid \($0)" } ?? "running"), \(hiddenFromDock ? "hidden" : "visible")"
            case .notRunning: "not running"
            }
        }
    }

    public var displayState: DisplayState {
        if requiresReAdd { return .requiresReAdd }
        guard running else { return .notRunning }
        return .running(pid: pid, hiddenFromDock: hiddenFromDock)
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
        categoryIdentifier: String?,
        requiresReAdd: Bool = false,
        version: AppVersion? = nil
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
        self.requiresReAdd = requiresReAdd
        self.version = version
    }
}
