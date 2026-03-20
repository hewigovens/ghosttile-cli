import AppKit
import Combine
import GhostTileCore

@MainActor
class AppViewModel: ObservableObject {
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var dockVisible = false
    @Published var sudoCommand: String?

    let managedAppsStore: ManagedAppsStore
    let dockVisibilityController: DockVisibilityController
    private(set) lazy var actionHandler = AppActionHandler(viewModel: self)
    private(set) lazy var attentionManager = AttentionObserverManager(viewModel: self)

    var apps: [ManagedAppItem] { managedAppsStore.apps }
    var hiddenApps: [ManagedAppItem] { apps.filter(\.isHidden) }
    var loading: Set<String> { actionHandler.loading }
    var cliPath: String { CLIPaths.resolved }

    private var observers: [NSObjectProtocol] = []
    private var pendingPresentationRefresh: DispatchWorkItem?
    private var storeSubscriptions: Set<AnyCancellable> = []

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
                self?.attentionManager.sync(bundleIds: bundleIds)
            }
            .store(in: &storeSubscriptions)
    }

    private func initializeState() {
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

    // MARK: - State

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

    func managedApp(bundleId: String) -> ManagedAppItem? {
        hiddenApps.first(where: { $0.id == bundleId })
    }

    func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func scheduleRefresh(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.refresh()
        }
    }

    func recordSponsorUse() {
        Task { @MainActor in
            SponsorNudgeController.shared.recordMeaningfulUse()
        }
    }

    // MARK: - Dock Visibility

    func autoHideIfNeeded(_ bundleId: String) {
        let autoHide = UserDefaults.standard.object(forKey: "autoHideOnLaunch") as? Bool ?? true
        dockVisibilityController.autoHideIfNeeded(bundleId, autoHideEnabled: autoHide)
    }

    func reapplyHidden() {
        dockVisibilityController.reapplyHiddenState()
        scheduleRefresh(after: 0.5)
    }

    func toggleSelfDock(openWindow: (() -> Void)? = nil) {
        if dockVisible {
            for window in NSApp.windows where window.title == "GhostTile" {
                window.close()
            }
            NSApp.setActivationPolicy(.accessory)
            dockVisible = false
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            dockVisible = true
            openWindow?()
        }
        UserDefaults.standard.set(dockVisible, forKey: "showInDock")
    }

    // MARK: - Action Forwarding

    func hideRunningApp(_ app: ManagedAppItem) { actionHandler.hideRunningApp(app) }
    func setDockVisibility(_ app: ManagedAppItem, hidden: Bool) { actionHandler.setDockVisibility(app, hidden: hidden) }
    func activateManagedApp(_ app: ManagedAppItem) { actionHandler.activateManagedApp(app) }
    func revealAppInFinder(_ app: ManagedAppItem) { actionHandler.revealAppInFinder(app) }
    func handleAttentionNotificationClick(bundleId: String) { actionHandler.handleAttentionNotificationClick(bundleId: bundleId) }
    func removeApp(_ app: ManagedAppItem) { actionHandler.removeApp(app) }
    func hideByURL(_ url: URL) { actionHandler.hideByURL(url) }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in observers { nc.removeObserver(observer) }
    }
}
