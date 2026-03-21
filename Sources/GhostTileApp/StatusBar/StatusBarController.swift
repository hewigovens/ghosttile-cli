import AppKit
import GhostTileCore
import KeyboardShortcuts
import SwiftUI

@MainActor
class StatusBarController: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    let viewModel: AppViewModel
    let showMainWindowAction: () -> Void
    let showOverview: () -> Void
    var settingsWindow: NSWindow?
    private lazy var menuBuilder = StatusBarMenuBuilder(controller: self)

    init(
        viewModel: AppViewModel,
        showMainWindow: @escaping () -> Void,
        showOverview: @escaping () -> Void
    ) {
        self.viewModel = viewModel
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
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        center(window: window, on: currentScreen())
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func openOverview() {
        showOverview()
    }

    @objc func quitApp() {
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
