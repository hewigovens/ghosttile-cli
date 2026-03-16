import AppKit
import GhostTileCore
import KeyboardShortcuts
import SwiftUI

@MainActor
class StatusBarController: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    let vm: AppViewModel
    let showMainWindowAction: () -> Void
    let showOverview: () -> Void
    var settingsWindow: NSWindow?

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

}
