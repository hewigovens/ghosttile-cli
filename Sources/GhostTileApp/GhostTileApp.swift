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

    func applicationDidBecomeActive(_ notification: Notification) {
        vm?.refreshForPresentation()
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
    @State private var overviewController: OverviewWindowController?
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.identifier?.rawValue.contains("main") == true || window.title == "GhostTile" {
                window.makeKeyAndOrderFront(nil)
                vm.refreshForPresentation()
                SponsorNudgeController.shared.considerPrompt()
                return
            }
        }
        vm.refreshForPresentation()
        SponsorNudgeController.shared.considerPrompt()
    }

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
                if overviewController == nil {
                    overviewController = OverviewWindowController(viewModel: vm)
                }
                if let overviewController {
                    ShortcutController.shared.start(
                        overviewController: overviewController,
                        showMainWindow: showMainWindow
                    )
                }
                if statusBar == nil {
                    statusBar = StatusBarController(
                        vm: vm,
                        showMainWindow: showMainWindow,
                        showOverview: {
                            overviewController?.toggle()
                        }
                    )
                }
                AttentionNotificationController.shared.start(viewModel: vm)
                appDelegate.vm = vm
                SponsorNudgeController.shared.considerPrompt()
            }
        }
        .defaultSize(width: 1040, height: 760)
        .windowResizability(onboardingComplete ? .contentMinSize : .contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
        }
    }
}
