import AppKit
import GhostTileCore
import KeyboardShortcuts
import SwiftUI

@MainActor
class StatusBarController: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    let viewModel: AppViewModel
    let updater: SparkleUpdater
    let showMainWindowAction: () -> Void
    let showOverview: () -> Void
    let showSettings: () -> Void
    private lazy var menuBuilder = StatusBarMenuBuilder(controller: self)

    init(
        viewModel: AppViewModel,
        updater: SparkleUpdater,
        showMainWindow: @escaping () -> Void,
        showOverview: @escaping () -> Void,
        showSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.updater = updater
        self.showMainWindowAction = showMainWindow
        self.showOverview = showOverview
        self.showSettings = showSettings
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
                    accessibilityDescription: "GhostTile"
                )
            }
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        KeyboardShortcuts.disable(.openMainWindow, .openOverview)
        menuBuilder.rebuild(menu)
    }

    func menuDidClose(_: NSMenu) {
        KeyboardShortcuts.enable(.openMainWindow, .openOverview)
    }

    // MARK: - Managed App Actions

    @objc func activateManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        viewModel.activateManagedApp(app)
    }

    @objc func showManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        viewModel.setDockVisibility(app, hidden: false)
    }

    @objc func hideManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        viewModel.setDockVisibility(app, hidden: true)
    }

    @objc func removeManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        viewModel.removeApp(app)
    }

    func managedApp(from sender: NSMenuItem) -> ManagedAppItem? {
        guard let bundleId = sender.representedObject as? String else { return nil }
        return viewModel.managedApp(bundleId: bundleId)
    }

    // MARK: - Window Actions

    @objc func toggleDock() {
        viewModel.toggleSelfDock {
            for window in NSApp.windows where window.identifier?.rawValue.contains("main") == true {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    @objc func showMainWindow() {
        showMainWindowAction()
    }

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        showSettings()
    }

    @objc func openOverview() {
        showOverview()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
