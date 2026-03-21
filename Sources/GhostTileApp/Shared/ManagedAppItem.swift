import AppKit
import GhostTileCore
import LSAppCategory
import SwiftUI

struct ManagedAppItem: Identifiable {
    let record: ManagedAppRecord
    let icon: NSImage
    let category: AppCategory

    var id: String {
        record.bundleId
    }

    var name: String {
        record.name
    }

    var appPath: String {
        record.appPath
    }

    var binaryPath: String {
        record.binaryPath
    }

    var isHidden: Bool {
        record.managed
    }

    var isSIPProtected: Bool {
        record.isSIPProtected
    }

    var isRunning: Bool {
        record.running
    }

    var isHiddenFromDock: Bool {
        record.hiddenFromDock
    }

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

    func menuItem(icon: NSImage) -> NSMenuItem {
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.image = {
            if let copy = icon.copy() as? NSImage {
                copy.size = NSSize(width: 16, height: 16)
                return copy
            }
            return icon
        }()
        return item
    }

    func visibilityMenuItems(
        target: AnyObject,
        hideAction: Selector,
        showAction: Selector,
        activateAction: Selector
    ) -> [NSMenuItem] {
        let hide = NSMenuItem(title: "Hide from Dock", action: hideAction, keyEquivalent: "")
        hide.target = target
        hide.representedObject = id
        hide.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
        hide.isEnabled = isRunning && !isHiddenFromDock

        let show = NSMenuItem(title: "Show in Dock", action: showAction, keyEquivalent: "")
        show.target = target
        show.representedObject = id
        show.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        show.isEnabled = isRunning && isHiddenFromDock

        let activate = NSMenuItem(title: isRunning ? "Activate" : "Launch", action: activateAction, keyEquivalent: "")
        activate.target = target
        activate.representedObject = id
        activate.image = NSImage(
            systemSymbolName: isRunning ? "arrow.up.forward.app" : "play",
            accessibilityDescription: nil
        )

        return [hide, show, activate]
    }

    func matches(query: String) -> Bool {
        let needle = query.lowercased()
        return name.lowercased().contains(needle)
            || id.lowercased().contains(needle)
            || appPath.lowercased().contains(needle)
    }
}

extension [ManagedAppItem] {
    func filtered(by query: String) -> [ManagedAppItem] {
        guard !query.isEmpty else { return self }
        return filter { $0.matches(query: query) }
    }
}
