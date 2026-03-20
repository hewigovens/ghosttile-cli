import AppKit
import GhostTileCore

@MainActor
final class AppActionHandler {
    static let postOperationRefreshDelay: TimeInterval = 1.5

    private weak var viewModel: AppViewModel?
    var loading: Set<String> = []

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    func hideRunningApp(_ app: ManagedAppItem) {
        guard let vm = viewModel, !loading.contains(app.id) else { return }

        if app.isSIPProtected {
            vm.showError(message: "\(app.name) is system-protected and cannot be hidden.")
            return
        }

        let info = app.appInfo
        let cli = vm.cliPath
        performAsync(for: app.id) {
            try AppOperations.hideApp(info, cliPath: cli)
        } onResult: { [weak self, weak vm] result in
            switch result {
            case .hidden:
                vm?.recordSponsorUse()
            case let .requiresSudo(command):
                vm?.sudoCommand = command
                self?.loading.remove(info.bundleId)
            }
        }
    }

    func setDockVisibility(_ app: ManagedAppItem, hidden: Bool) {
        guard let vm = viewModel, app.isRunning else { return }
        vm.dockVisibilityController.send(bundleId: app.id, hidden: hidden)
        vm.scheduleRefresh(after: 0.5)
        vm.recordSponsorUse()
    }

    func activateManagedApp(_ app: ManagedAppItem) {
        guard let vm = viewModel else { return }

        if let running = AppManager.runningApps(app.id).first {
            running.activate()
            vm.recordSponsorUse()
            return
        }

        let info = app.appInfo
        performAsync(for: app.id, showLoading: false) {
            try AppManager.launchManagedVisible(info)
        } onResult: { [weak vm] _ in
            vm?.recordSponsorUse()
            vm?.scheduleRefresh(after: 0.75)
        }
    }

    func revealAppInFinder(_ app: ManagedAppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.appPath)])
    }

    func handleAttentionNotificationClick(bundleId: String) {
        guard let vm = viewModel,
              let app = vm.managedApp(bundleId: bundleId) else { return }

        if app.isRunning, app.isHiddenFromDock {
            setDockVisibility(app, hidden: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.activateManagedApp(app)
            }
            return
        }

        activateManagedApp(app)
    }

    func removeApp(_ app: ManagedAppItem) {
        guard let vm = viewModel, !loading.contains(app.id) else { return }

        let info = app.appInfo
        let wasRunning = app.isRunning
        let cli = vm.cliPath
        let refreshDelay: TimeInterval = wasRunning ? Self.postOperationRefreshDelay : 0

        performAsync(for: app.id, refreshDelay: refreshDelay) {
            try AppOperations.removeApp(info, wasRunning: wasRunning)
        } onResult: { [weak vm] _ in
            vm?.recordSponsorUse()
        } onError: { [weak vm] _ in
            vm?.sudoCommand = "sudo \(cli) restore \(info.bundleId)"
        }
    }

    func hideByURL(_ url: URL) {
        guard let vm = viewModel,
              let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier,
              let execURL = bundle.executableURL
        else { return }

        if Config.load().hidden[bundleId] != nil { return }

        let appPath = url.path
        if AppManager.isSIPProtected(appPath) || AppManager.isAppleFirstParty(appPath) {
            vm.showError(message: "\(bundle.infoDictionary?["CFBundleName"] as? String ?? bundleId) cannot be hidden.")
            return
        }

        if let existing = vm.apps.first(where: { $0.id == bundleId }) {
            hideRunningApp(existing)
        } else {
            let name = bundle.infoDictionary?["CFBundleName"] as? String
                ?? FileManager.default.displayName(atPath: appPath)
            let icon = NSWorkspace.shared.icon(forFile: appPath)
            let record = ManagedAppRecord(
                bundleId: bundleId,
                name: name,
                appPath: appPath,
                binaryPath: execURL.path,
                managed: false,
                running: false,
                hiddenFromDock: false,
                pid: nil,
                isSIPProtected: false,
                categoryIdentifier: nil
            )
            hideRunningApp(ManagedAppItem(record: record, icon: icon, category: .other))
        }
    }

    // MARK: - Async Helper

    func performAsync<T>(
        for bundleId: String,
        showLoading: Bool = true,
        refreshDelay: TimeInterval = 1.5,
        work: @escaping () throws -> T,
        onResult: @escaping @MainActor (T) -> Void = { _ in },
        onError: (@MainActor (Error) -> Void)? = nil
    ) {
        if showLoading { loading.insert(bundleId) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak viewModel] in
            do {
                let result = try work()
                Task { @MainActor in
                    onResult(result)
                }
            } catch {
                Log.error("Operation failed for \(bundleId): \(error)")
                Task { @MainActor [weak viewModel] in
                    if let onError {
                        onError(error)
                    } else {
                        viewModel?.errorMessage = error.localizedDescription
                        viewModel?.showError = true
                    }
                }
            }
            Task { @MainActor [weak self, weak viewModel] in
                self?.loading.remove(bundleId)
                viewModel?.scheduleRefresh(after: refreshDelay)
            }
        }
    }
}
