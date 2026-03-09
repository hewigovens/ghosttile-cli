import AppKit
import GhostTileCore
import SwiftUI

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let vm: AppViewModel

    init(vm: AppViewModel) {
        self.vm = vm
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            let execURL = Bundle.main.executableURL
                ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            let pdfURL = execURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/status_menu_v.pdf")

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
        menu.removeAllItems()

        menu.addItem(makeItem("Show Main Window", action: #selector(showMainWindow)))

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
                let item = makeItem(app.name, action: #selector(activateApp(_:)))
                item.representedObject = app.id
                if let img = app.icon.copy() as? NSImage {
                    img.size = NSSize(width: 16, height: 16)
                    item.image = img
                } else {
                    item.image = app.icon
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit GhostTile", action: #selector(quitApp), key: "q"))
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func activateApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate()
        } else if let hidden = vm.hiddenApps.first(where: { $0.id == bundleId }) {
            try? AppManager.launchNormal(hidden.appPath)
        }
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
        vm.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak vm] in
            vm?.refresh()
        }
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.identifier?.rawValue.contains("main") == true || window.title == "GhostTile" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    @objc private func openSettings() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "GhostTile Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
