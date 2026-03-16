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

    func makeManagedAppItem(_ app: AppViewModel.AppItem) -> NSMenuItem {
        let item = NSMenuItem(title: app.name, action: nil, keyEquivalent: "")
        item.image = resizedIcon(app.icon)
        item.submenu = managedAppSubmenu(for: app)
        return item
    }

    func managedAppSubmenu(for app: AppViewModel.AppItem) -> NSMenu {
        let submenu = NSMenu(title: app.name)

        let stateItem = NSMenuItem(title: managedAppStateText(app), action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        submenu.addItem(stateItem)
        submenu.addItem(.separator())

        let activate = makeItem(app.isRunning ? "Activate" : "Launch", action: #selector(activateManagedApp(_:)))
        activate.representedObject = app.id
        submenu.addItem(activate)

        let show = makeItem("Show in Dock", action: #selector(showManagedApp(_:)))
        show.representedObject = app.id
        show.isEnabled = app.isRunning && app.isHiddenFromDock
        submenu.addItem(show)

        let hide = makeItem("Hide from Dock", action: #selector(hideManagedApp(_:)))
        hide.representedObject = app.id
        hide.isEnabled = app.isRunning && !app.isHiddenFromDock
        submenu.addItem(hide)

        submenu.addItem(.separator())

        let remove = makeItem("Remove from GhostTile", action: #selector(removeManagedApp(_:)))
        remove.representedObject = app.id
        submenu.addItem(remove)
        return submenu
    }

    func managedAppStateText(_ app: AppViewModel.AppItem) -> String {
        if !app.isRunning {
            return "Not Running"
        }
        return app.isHiddenFromDock ? "Running Hidden" : "Running Visible"
    }

    func resizedIcon(_ image: NSImage) -> NSImage {
        if let copy = image.copy() as? NSImage {
            copy.size = NSSize(width: 16, height: 16)
            return copy
        }
        return image
    }

    func managedApp(from sender: NSMenuItem) -> AppViewModel.AppItem? {
        guard let bundleId = sender.representedObject as? String else { return nil }
        return vm.managedApp(bundleId: bundleId)
    }
}
