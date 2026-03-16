import AppKit
import GhostTileCore
import LSAppCategory
import os.log

class AppViewModel: ObservableObject {
    static let postOperationRefreshDelay: TimeInterval = 1.5
    static let attentionNotificationCooldown: TimeInterval = 10

    struct AppItem: Identifiable {
        let id: String
        let name: String
        let icon: NSImage
        let appPath: String
        let binaryPath: String
        let category: AppCategory
        var isHidden: Bool
        var isSIPProtected: Bool
        var isRunning: Bool
        var isHiddenFromDock: Bool
    }

    @Published var apps: [AppItem] = []
    @Published var loading: Set<String> = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var dockVisible = false
    @Published var sudoCommand: String?

    var hiddenCount: Int { apps.filter(\.isHidden).count }
    var hiddenApps: [AppItem] { apps.filter(\.isHidden) }
    var visibleApps: [AppItem] {
        apps.filter { !$0.isHidden && !$0.isSIPProtected && !$0.id.hasPrefix("com.apple.") }
    }

    var observers: [NSObjectProtocol] = []
    var attentionObservers: [String: NSObjectProtocol] = [:]
    var lastAttentionNotificationAt: [String: Date] = [:]
    var configDirectoryMonitor: DispatchSourceFileSystemObject?
    var configFileMonitor: DispatchSourceFileSystemObject?
    var pendingPresentationRefresh: DispatchWorkItem?

    var cliPath: String {
        let installed = "/usr/local/bin/ghosttile"
        if FileManager.default.fileExists(atPath: installed) { return installed }
        let bundled = BundledResources.resourcePath(named: "ghosttile-cli")
        if FileManager.default.fileExists(atPath: bundled) { return bundled }
        return "ghosttile"
    }

    init() {
        // Restore saved dock visibility preference
        let savedDockVisible = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? false
        if savedDockVisible {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        dockVisible = savedDockVisible
        refresh()
        reapplyHidden()

        let nc = NSWorkspace.shared.notificationCenter
        observers.append(
            nc.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil, queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                    let bundleId = app.bundleIdentifier
                {
                    self.autoHideIfNeeded(bundleId)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.refresh()
                }
            })
        observers.append(
            nc.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                self?.refresh()
            })

        watchConfigFile()
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in observers { nc.removeObserver(observer) }
        let dnc = DistributedNotificationCenter.default()
        for observer in attentionObservers.values { dnc.removeObserver(observer) }
        configDirectoryMonitor?.cancel()
        configFileMonitor?.cancel()
    }
}
