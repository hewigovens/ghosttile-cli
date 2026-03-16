import AppKit
import GhostTileCore
import KeyboardShortcuts
import SwiftUI

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let vm: AppViewModel
    private let showMainWindowAction: () -> Void
    private let showOverview: () -> Void
    private var settingsWindow: NSWindow?

    init(
        vm: AppViewModel,
        showMainWindow: @escaping () -> Void,
        showOverview: @escaping () -> Void
    ) {
        self.vm = vm
        self.showMainWindowAction = showMainWindow
        self.showOverview = showOverview
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            let pdfURL = BundledResources.resourceURL(named: "status_menu_v.pdf")

            if let img = NSImage(contentsOf: pdfURL) {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            } else {
                button.image = NSImage(
                    systemSymbolName: "eye.slash",
                    accessibilityDescription: "GhostTile")
            }
        }
    }

    // Rebuild menu each time it opens
    func menuWillOpen(_ menu: NSMenu) {
        KeyboardShortcuts.disable(.openMainWindow, .openOverview)
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

        let header = NSMenuItem(title: "Managed Apps", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let managed = vm.hiddenApps
        if managed.isEmpty {
            let empty = NSMenuItem(title: "No managed apps", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for app in managed {
                menu.addItem(makeManagedAppItem(app))
            }
        }

        menu.addItem(.separator())
        menu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit GhostTile", action: #selector(quitApp), key: "q"))
    }

    func menuDidClose(_ menu: NSMenu) {
        KeyboardShortcuts.enable(.openMainWindow, .openOverview)
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func makeManagedAppItem(_ app: AppViewModel.AppItem) -> NSMenuItem {
        let item = NSMenuItem(title: app.name, action: nil, keyEquivalent: "")
        item.image = resizedIcon(app.icon)

        let submenu = NSMenu(title: app.name)

        let stateText: String
        if !app.isRunning {
            stateText = "Not Running"
        } else if app.isHiddenFromDock {
            stateText = "Running Hidden"
        } else {
            stateText = "Running Visible"
        }
        let stateItem = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
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

        item.submenu = submenu
        return item
    }

    private func resizedIcon(_ image: NSImage) -> NSImage {
        if let copy = image.copy() as? NSImage {
            copy.size = NSSize(width: 16, height: 16)
            return copy
        }
        return image
    }

    private func managedApp(from sender: NSMenuItem) -> AppViewModel.AppItem? {
        guard let bundleId = sender.representedObject as? String else { return nil }
        return vm.managedApp(bundleId: bundleId)
    }

    @objc private func activateManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.activateManagedApp(app)
    }

    @objc private func showManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.showAppInDock(app)
    }

    @objc private func hideManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.hideAppFromDock(app)
    }

    @objc private func removeManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.removeApp(app)
    }

    @objc private func toggleDock() {
        vm.toggleSelfDock {
            for window in NSApp.windows where window.identifier?.rawValue.contains("main") == true {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    @objc private func showMainWindow() {
        showMainWindowAction()
    }

    @objc private func openSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        center(window: window, on: currentScreen())
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openOverview() {
        showOverview()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "GhostTile Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 700))
        return window
    }

    private func currentScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }

    private func center(window: NSWindow, on screen: NSScreen?) {
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        var frame = window.frame
        frame.origin.x = visibleFrame.midX - (frame.width / 2)
        frame.origin.y = visibleFrame.midY - (frame.height / 2)
        window.setFrame(frame, display: false)
    }
}
