import AppKit
import KeyboardShortcuts

extension StatusBarController {
    func menuWillOpen(_ menu: NSMenu) {
        KeyboardShortcuts.disable(.openMainWindow, .openOverview)
        rebuildMenu(menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        KeyboardShortcuts.enable(.openMainWindow, .openOverview)
    }

    func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let mainWindowItem = makeItem("Show Main Window", action: #selector(showMainWindow))
        mainWindowItem.setShortcut(for: .openMainWindow)
        menu.addItem(mainWindowItem)

        let overviewItem = makeItem("Show Overview", action: #selector(openOverview))
        overviewItem.setShortcut(for: .openOverview)
        menu.addItem(overviewItem)

        let dockTitle = vm.dockVisible ? "Hide from Dock" : "Show in Dock"
        menu.addItem(makeItem(dockTitle, action: #selector(toggleDock)))

        menu.addItem(.separator())
        addManagedAppsSection(to: menu)
        menu.addItem(.separator())
        menu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit GhostTile", action: #selector(quitApp), key: "q"))
    }

    func addManagedAppsSection(to menu: NSMenu) {
        let header = NSMenuItem(title: "Managed Apps", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let managed = vm.hiddenApps
        if managed.isEmpty {
            let empty = NSMenuItem(title: "No managed apps", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for app in managed {
            menu.addItem(makeManagedAppItem(app))
        }
    }

    func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func makeManagedAppItem(_ app: ManagedAppItem) -> NSMenuItem {
        let item = app.menuItem(icon: app.icon)
        item.submenu = managedAppSubmenu(for: app)
        return item
    }

    func managedAppSubmenu(for app: ManagedAppItem) -> NSMenu {
        let submenu = NSMenu(title: app.name)

        let stateText = app.isRunning
            ? (app.isHiddenFromDock ? "Running Hidden" : "Running Visible")
            : "Not Running"
        let stateItem = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        submenu.addItem(stateItem)
        submenu.addItem(.separator())

        for item in app.visibilityMenuItems(
            target: self,
            hideAction: #selector(hideManagedApp(_:)),
            showAction: #selector(showManagedApp(_:)),
            activateAction: #selector(activateManagedApp(_:))
        ) {
            submenu.addItem(item)
        }

        submenu.addItem(.separator())

        let remove = makeItem("Remove from GhostTile", action: #selector(removeManagedApp(_:)))
        remove.representedObject = app.id
        remove.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        submenu.addItem(remove)
        return submenu
    }

    func managedApp(from sender: NSMenuItem) -> ManagedAppItem? {
        guard let bundleId = sender.representedObject as? String else { return nil }
        return vm.managedApp(bundleId: bundleId)
    }
}
