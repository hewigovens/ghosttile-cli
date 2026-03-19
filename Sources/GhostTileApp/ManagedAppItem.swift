import AppKit
import GhostTileCore
import LSAppCategory
import SwiftUI

struct ManagedAppItem: Identifiable {
    let record: ManagedAppRecord
    let icon: NSImage
    let category: AppCategory

    var id: String { record.bundleId }
    var name: String { record.name }
    var appPath: String { record.appPath }
    var binaryPath: String { record.binaryPath }
    var isHidden: Bool { record.managed }
    var isSIPProtected: Bool { record.isSIPProtected }
    var isRunning: Bool { record.running }
    var isHiddenFromDock: Bool { record.hiddenFromDock }

    var appInfo: AppInfo {
        AppInfo(bundleId: id, name: name, appPath: appPath, binaryPath: binaryPath)
    }

    var statusText: String {
        if !isRunning { return "Not Running" }
        return isHiddenFromDock ? "Hidden" : "Visible"
    }

    var statusColor: Color {
        if !isRunning { return .secondary }
        return isHiddenFromDock ? .orange : .green
    }

    func matches(query: String) -> Bool {
        let needle = query.lowercased()
        return name.lowercased().contains(needle)
            || id.lowercased().contains(needle)
            || appPath.lowercased().contains(needle)
    }
}

extension Array where Element == ManagedAppItem {
    func filtered(by query: String) -> [ManagedAppItem] {
        guard !query.isEmpty else { return self }
        return filter { $0.matches(query: query) }
    }
}
