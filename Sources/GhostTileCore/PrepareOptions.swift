import Foundation

/// Flags controlling how an app is prepared (patched + re-signed).
public struct PrepareOptions: Sendable, Equatable {
    /// Proceed despite compatibility warnings (TCC features that may break).
    public var acceptWarnings: Bool
    /// Overwrite an existing backup with the current binary (re-adding an updated app).
    public var refreshBackup: Bool
    /// Strip identity/sandbox entitlements and run unsandboxed (app-group apps on Tahoe).
    public var unsandbox: Bool

    public init(acceptWarnings: Bool = false, refreshBackup: Bool = false, unsandbox: Bool = false) {
        self.acceptWarnings = acceptWarnings
        self.refreshBackup = refreshBackup
        self.unsandbox = unsandbox
    }
}
