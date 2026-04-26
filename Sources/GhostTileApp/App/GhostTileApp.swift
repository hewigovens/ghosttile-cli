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
    @Environment(\.openSettings) private var openSettings
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var updater = SparkleUpdater()
    @State private var statusBar: StatusBarController?
    @State private var overviewController: OverviewWindowController?
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    private func showAboutWindow() {
        if let existing = NSApp.windows.first(where: { $0.title == "About GhostTile" }) {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
        window.title = "About GhostTile"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 340, height: 420))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

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
                        updater: updater,
                        showMainWindow: showMainWindow,
                        showOverview: {
                            overviewController?.toggle()
                        },
                        showSettings: {
                            openSettings()
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
            SettingsView(updater: updater)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About GhostTile") {
                    showAboutWindow()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}
