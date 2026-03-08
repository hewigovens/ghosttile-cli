import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var vm: AppViewModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Hide from Dock", action: #selector(hideFromDock), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func hideFromDock() {
        vm?.toggleSelfDock()
    }
}

@main
struct GhostTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vm = AppViewModel()
    @State private var statusBar: StatusBarController?
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some Scene {
        Window("GhostTile", id: "main") {
            Group {
                if onboardingComplete {
                    MainWindowView(vm: vm)
                } else {
                    OnboardingView(isComplete: $onboardingComplete)
                }
            }
            .onAppear {
                if statusBar == nil {
                    statusBar = StatusBarController(vm: vm)
                }
                appDelegate.vm = vm
            }
        }
        .defaultSize(width: 480, height: 520)
        .windowResizability(onboardingComplete ? .contentMinSize : .contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
        }
    }
}
