import AppKit
import SwiftUI

extension StatusBarController {
    @objc func toggleDock() {
        vm.toggleSelfDock {
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

    func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "GhostTile Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 700))
        return window
    }

    func currentScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }

    func center(window: NSWindow, on screen: NSScreen?) {
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        var frame = window.frame
        frame.origin.x = visibleFrame.midX - (frame.width / 2)
        frame.origin.y = visibleFrame.midY - (frame.height / 2)
        window.setFrame(frame, display: false)
    }
}
