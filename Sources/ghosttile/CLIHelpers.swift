import AppKit
import Foundation
import GhostTileCore

func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    if let output = String(data: data, encoding: .utf8) {
        print(output)
    }
}

func resolveManaged(_ query: String) throws -> (String, HiddenApp) {
    let config = Config.load()
    let q = query.lowercased()

    let match = config.hidden.first {
        $0.key.lowercased().contains(q)
            || $0.value.name.lowercased().contains(q)
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

func prepareIfNeeded(_ app: AppInfo, force: Bool) throws {
    let shouldPrepare = try force || AppManager.needsPreparation(app)
    guard shouldPrepare else { return }
    print("Preparing \(app.name)...")
    try AppManager.prepare(app)
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
