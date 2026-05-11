import AppKit
import Foundation
import GhostTileCore

func printJSON(_ value: some Encodable) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    if let output = String(data: data, encoding: .utf8) {
        print(output)
    }
}

func resolveManaged(_ query: String) throws -> (String, HiddenApp) {
    let config = Config.load()
    let queryLower = query.lowercased()

    let match = config.hidden.first {
        $0.key.lowercased().contains(queryLower)
            || $0.value.name.lowercased().contains(queryLower)
    }

    guard let result = match else {
        throw GhostTileError(
            "'\(query)' is not managed. Run 'ghosttile manage <app>' first."
        )
    }

    return result
}

func isRunning(_ bundleId: String) -> Bool {
    AppManager.isRunning(bundleId)
}

func validateNotSIPProtected(_ app: AppInfo) throws {
    if AppManager.isSIPProtected(app.appPath) {
        throw GhostTileError("\(app.name) is in a SIP-protected location.")
    }
}

func validateCompatibility(_ app: AppInfo, acceptWarnings: Bool) throws {
    switch try AppManager.assessCompatibility(app) {
    case .compatible:
        return
    case let .unsupported(reason):
        throw GhostTileError(reason)
    case let .warnings(warnings):
        let stderr = FileHandle.standardError
        stderr.write(Data("Compatibility warnings for \(app.name):\n".utf8))
        for warning in warnings {
            stderr.write(Data("  • \(warning.impact) (\(warning.entitlement))\n".utf8))
        }
        if acceptWarnings {
            stderr.write(Data("Continuing because --accept-warnings was set.\n".utf8))
            return
        }
        // Require an explicit flag for non-interactive runs so scripts can't silently proceed.
        if isatty(0) == 0 {
            throw GhostTileError(
                "\(app.name) may lose features after preparation. Re-run with --accept-warnings to proceed."
            )
        }
        stderr.write(Data("Continue anyway? [y/N]: ".utf8))
        let response = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        guard response == "y" || response == "yes" else {
            throw GhostTileError("Cancelled by user.")
        }
    }
}

func prepareIfNeeded(_ app: AppInfo, force: Bool, acceptWarnings: Bool = false) throws {
    let shouldPrepare = try force || AppManager.needsPreparation(app)
    guard shouldPrepare else { return }
    print("Preparing \(app.name)...")
    try AppManager.prepare(app, acceptWarnings: acceptWarnings)
}

func addToConfig(_ app: AppInfo) throws {
    try Config.addHidden(app)
}

func sendVisibilityNotification(_ query: String, action: ManagedAppNotificationAction) throws {
    let (bundleId, hiddenApp) = try resolveManaged(query)

    guard isRunning(bundleId) else {
        print("\(hiddenApp.name) is not running.")
        return
    }

    ManagedAppNotifications.post(bundleId: bundleId, action: action)
    let verb = action == .hide ? "hidden from" : "shown in"
    print("\(hiddenApp.name) \(verb) Dock.")
}
