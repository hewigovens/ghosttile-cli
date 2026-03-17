import AppKit
import Combine
import GhostTileCore
import os.log

@MainActor
class AppViewModel: ObservableObject {
    static let postOperationRefreshDelay: TimeInterval = 1.5
    static let attentionNotificationCooldown: TimeInterval = 10

    @Published var loading: Set<String> = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var dockVisible = false
    @Published var sudoCommand: String?

    let managedAppsStore: ManagedAppsStore
    let dockVisibilityController: DockVisibilityController
    var apps: [ManagedAppItem] { managedAppsStore.apps }
    var hiddenApps: [ManagedAppItem] { apps.filter(\.isHidden) }

    var observers: [NSObjectProtocol] = []
    var attentionObservers: [String: NSObjectProtocol] = [:]
    var lastAttentionNotificationAt: [String: Date] = [:]
    var pendingPresentationRefresh: DispatchWorkItem?
    var storeSubscriptions: Set<AnyCancellable> = []

    var cliPath: String { CLIPaths.resolved }

    init() {
        self.managedAppsStore = ManagedAppsStore()
        self.dockVisibilityController = DockVisibilityController()
        configureStoreSubscriptions()
        initializeState()
    }

    init(
        managedAppsStore: ManagedAppsStore,
        dockVisibilityController: DockVisibilityController
    ) {
        self.managedAppsStore = managedAppsStore
        self.dockVisibilityController = dockVisibilityController
        configureStoreSubscriptions()
        initializeState()
    }

    private func configureStoreSubscriptions() {
        managedAppsStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeSubscriptions)

        managedAppsStore.$managedBundleIds
            .sink { [weak self] bundleIds in
                self?.syncAttentionObservers(bundleIds: bundleIds)
            }
            .store(in: &storeSubscriptions)
    }

    private func initializeState() {
        // Restore saved dock visibility preference
        let savedDockVisible = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? false
        if savedDockVisible {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        dockVisible = savedDockVisible
        managedAppsStore.startWatching()
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
                    Task { @MainActor [weak self] in
                        self?.autoHideIfNeeded(bundleId)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task { @MainActor [weak self] in
                        self?.refresh()
                    }
                }
            })
        observers.append(
            nc.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            })
    }

    func refresh() {
        managedAppsStore.refresh()
    }

    func refreshForPresentation() {
        pendingPresentationRefresh?.cancel()
        refresh()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refresh()
        }
        pendingPresentationRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in observers { nc.removeObserver(observer) }
        let dnc = DistributedNotificationCenter.default()
        for observer in attentionObservers.values { dnc.removeObserver(observer) }
    }
}
