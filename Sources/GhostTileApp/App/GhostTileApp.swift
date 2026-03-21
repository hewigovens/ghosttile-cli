import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: AppViewModel?

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        if let viewModel, !viewModel.hiddenApps.isEmpty {
            for app in viewModel.hiddenApps {
                let item = app.menuItem(icon: app.icon)
                let submenu = NSMenu(title: app.name)
                for menuItem in app.visibilityMenuItems(
                    target: self,
                    hideAction: #selector(dockMenuHideApp(_:)),
                    showAction: #selector(dockMenuShowApp(_:)),
                    activateAction: #selector(dockMenuActivateApp(_:))
                ) {
                    submenu.addItem(menuItem)
                }
                item.submenu = submenu
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let hideItem = NSMenuItem(title: "Hide GhostTile from Dock", action: #selector(hideFromDock), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        return menu
    }

    func applicationDidBecomeActive(_: Notification) {
        viewModel?.refreshForPresentation()
    }

    @objc private func hideFromDock() {
        viewModel?.toggleSelfDock()
    }

    @objc private func dockMenuHideApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String,
              let app = viewModel?.managedApp(bundleId: bundleId) else { return }
        viewModel?.setDockVisibility(app, hidden: true)
    }

    @objc private func dockMenuShowApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String,
              let app = viewModel?.managedApp(bundleId: bundleId) else { return }
        viewModel?.setDockVisibility(app, hidden: false)
    }

    @objc private func dockMenuActivateApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String,
              let app = viewModel?.managedApp(bundleId: bundleId) else { return }
        viewModel?.activateManagedApp(app)
    }
}

@main
struct GhostTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @State private var statusBar: StatusBarController?
    @State private var overviewController: OverviewWindowController?
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.identifier?.rawValue.contains("main") == true || window.title == "GhostTile" {
                window.makeKeyAndOrderFront(nil)
                viewModel.refreshForPresentation()
                SponsorNudgeController.shared.considerPrompt()
                return
            }
        }
        viewModel.refreshForPresentation()
        SponsorNudgeController.shared.considerPrompt()
    }

    var body: some Scene {
        Window("GhostTile", id: "main") {
            Group {
                if onboardingComplete {
                    MainWindowView(appViewModel: viewModel)
                } else {
                    OnboardingView(isComplete: $onboardingComplete)
                }
            }
            .onAppear {
                if overviewController == nil {
                    overviewController = OverviewWindowController(viewModel: viewModel)
                }
                if let overviewController {
                    ShortcutController.shared.start(
                        overviewController: overviewController,
                        showMainWindow: showMainWindow
                    )
                }
                if statusBar == nil {
                    statusBar = StatusBarController(
                        viewModel: viewModel,
                        showMainWindow: showMainWindow,
                        showOverview: {
                            overviewController?.toggle()
                        }
                    )
                }
                AttentionNotificationController.shared.start(viewModel: viewModel)
                appDelegate.viewModel = viewModel
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
