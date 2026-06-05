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

    var requiresReAdd: Bool {
        record.requiresReAdd
    }

    var displayState: ManagedAppRecord.DisplayState {
        record.displayState
    }

    var versionText: String? {
        record.version?.displayString
    }

    var appInfo: AppInfo {
        AppInfo(
            bundleId: id,
            name: name,
            appPath: appPath,
            binaryPath: binaryPath
        )
    }

    var statusText: String {
        displayState.label
    }

    var statusColor: Color {
        switch displayState {
        case .requiresReAdd: .red
        case let .running(_, hiddenFromDock): hiddenFromDock ? .orange : .green
        case .notRunning: .secondary
        }
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
        let hide = NSMenuItem(title: PrimaryAction.hideFromDock.menuTitle, action: hideAction, keyEquivalent: "")
        hide.target = target
        hide.representedObject = id
        hide.image = NSImage(systemSymbolName: PrimaryAction.hideFromDock.systemImage, accessibilityDescription: nil)
        hide.isEnabled = isRunning && !isHiddenFromDock && !requiresReAdd

        let show = NSMenuItem(title: PrimaryAction.showInDock.menuTitle, action: showAction, keyEquivalent: "")
        show.target = target
        show.representedObject = id
        show.image = NSImage(systemSymbolName: PrimaryAction.showInDock.systemImage, accessibilityDescription: nil)
        show.isEnabled = isRunning && isHiddenFromDock && !requiresReAdd

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

extension ManagedAppItem {
    /// The primary action a card surfaces for an app's state; centralizes the branching the cards used to repeat.
    enum PrimaryAction {
        case reAdd
        case showInDock
        case hideFromDock
        case launch

        var title: String {
            switch self {
            case .reAdd: "Re-add"
            case .showInDock: "Show"
            case .hideFromDock: "Hide"
            case .launch: "Launch"
            }
        }

        var systemImage: String {
            switch self {
            case .reAdd: "arrow.triangle.2.circlepath"
            case .showInDock: "eye"
            case .hideFromDock: "eye.slash"
            case .launch: "play.fill"
            }
        }

        /// Full label for menu items (context menus, status bar submenu).
        var menuTitle: String {
            switch self {
            case .reAdd: "Re-add to GhostTile"
            case .showInDock: "Show in Dock"
            case .hideFromDock: "Hide from Dock"
            case .launch: "Launch"
            }
        }
    }

    var primaryAction: PrimaryAction {
        if requiresReAdd { return .reAdd }
        if !isRunning { return .launch }
        return isHiddenFromDock ? .showInDock : .hideFromDock
    }
}

extension [ManagedAppItem] {
    func filtered(by query: String) -> [ManagedAppItem] {
        guard !query.isEmpty else { return self }
        return filter { $0.matches(query: query) }
    }
}
