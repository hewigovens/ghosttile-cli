import AppKit
import KeyboardShortcuts

@MainActor
struct StatusBarMenuBuilder {
    let controller: StatusBarController

    private var vm: AppViewModel {
        controller.vm
    }

    func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let mainWindowItem = makeItem("Show Main Window", action: #selector(StatusBarController.showMainWindow))
        mainWindowItem.setShortcut(for: .openMainWindow)
        menu.addItem(mainWindowItem)

        let overviewItem = makeItem("Show Overview", action: #selector(StatusBarController.openOverview))
        overviewItem.setShortcut(for: .openOverview)
        menu.addItem(overviewItem)

        let dockTitle = vm.dockVisible ? "Hide from Dock" : "Show in Dock"
        menu.addItem(makeItem(dockTitle, action: #selector(StatusBarController.toggleDock)))

        menu.addItem(.separator())
        addManagedAppsSection(to: menu)
        menu.addItem(.separator())
        menu.addItem(makeItem("Settings…", action: #selector(StatusBarController.openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit GhostTile", action: #selector(StatusBarController.quitApp), key: "q"))
    }

    private func addManagedAppsSection(to menu: NSMenu) {
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
            let item = app.menuItem(icon: app.icon)
            item.submenu = managedAppSubmenu(for: app)
            menu.addItem(item)
        }
    }

    private func managedAppSubmenu(for app: ManagedAppItem) -> NSMenu {
        let submenu = NSMenu(title: app.name)

        let stateText = app.isRunning
            ? (app.isHiddenFromDock ? "Running Hidden" : "Running Visible")
            : "Not Running"
        let stateItem = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        submenu.addItem(stateItem)
        submenu.addItem(.separator())

        for item in app.visibilityMenuItems(
            target: controller,
            hideAction: #selector(StatusBarController.hideManagedApp(_:)),
            showAction: #selector(StatusBarController.showManagedApp(_:)),
            activateAction: #selector(StatusBarController.activateManagedApp(_:))
        ) {
            submenu.addItem(item)
        }

        submenu.addItem(.separator())

        let remove = makeItem("Remove from GhostTile", action: #selector(StatusBarController.removeManagedApp(_:)))
        remove.representedObject = app.id
        remove.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        submenu.addItem(remove)
        return submenu
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = controller
        return item
    }
}
