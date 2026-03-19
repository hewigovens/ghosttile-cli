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

func sendVisibilityNotification(_ query: String, action: ManagedAppNotificationAction) throws {
    let (bundleId, hiddenApp) = try resolveManaged(query)

    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    guard !running.isEmpty else {
        print("\(hiddenApp.name) is not running.")
        return
    }

    ManagedAppNotifications.post(bundleId: bundleId, action: action)
    let verb = action == .hide ? "hidden from" : "shown in"
    print("\(hiddenApp.name) \(verb) Dock.")
}
