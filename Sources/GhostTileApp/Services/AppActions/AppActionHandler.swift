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
        manageApp(app)
    }

    func readdManagedApp(_ app: ManagedAppItem) {
        manageApp(app, forcePrepare: true, options: PrepareOptions(refreshBackup: true))
    }

    private func manageApp(
        _ app: ManagedAppItem,
        forcePrepare: Bool = false,
        options: PrepareOptions = .init()
    ) {
        guard let viewModel, !loading.contains(app.id) else { return }

        if app.isSIPProtected {
            viewModel.showError(message: "\(app.name) is system-protected and cannot be hidden.")
            return
        }

        guard ensureAppManagementPermission() else { return }

        let info = app.appInfo
        let cli = viewModel.cliPath
        performAsync(for: app.id) {
            try AppOperations.hideApp(info, cliPath: cli, forcePrepare: forcePrepare, options: options)
        } onResult: { [weak self, weak viewModel] result in
            switch result {
            case .hidden:
                viewModel?.recordSponsorUse()
            case let .requiresSudo(command):
                viewModel?.sudoCommand = command
            case let .requiresWarningConfirmation(warnings):
                Task { @MainActor [weak self] in
                    self?.confirmCompatibilityWarnings(for: app, warnings: warnings) { [weak self] in
                        var accepted = options
                        accepted.acceptWarnings = true
                        self?.manageApp(app, forcePrepare: forcePrepare, options: accepted)
                    }
                }
            case let .requiresUnsandboxConfirmation(reason):
                Task { @MainActor [weak self] in
                    self?.confirmUnsandbox(for: app, reason: reason) { [weak self] in
                        var unsandboxed = options
                        unsandboxed.unsandbox = true
                        self?.manageApp(app, forcePrepare: forcePrepare, options: unsandboxed)
                    }
                }
            }
        } onError: { [weak self, weak viewModel] error in
            if let gtError = error as? GhostTileError, case .appManagementDenied = gtError {
                self?.presentAppManagementPermissionAlert()
            } else {
                viewModel?.errorMessage = error.localizedDescription
                viewModel?.showError = true
            }
        }
    }

    /// Adhoc dev rebuilds reset TCC identity (cdhash changes); Developer-ID release updates don't.
    private func ensureAppManagementPermission() -> Bool {
        if AppManagementPermissionStatusReader.currentProcessIsAllowed() != false {
            return true
        }
        presentAppManagementPermissionAlert()
        return false
    }

    private func presentAppManagementPermissionAlert() {
        let openSettings = AlertPresenter.confirm(
            "GhostTile needs App Management permission",
            body: "Click Allow in the Privacy & Security notification on the top right corner,"
                + " or turn on GhostTile under System Settings → Privacy & Security → App Management."
                + "\n\nThen quit and relaunch GhostTile.",
            confirmButton: "Open System Settings"
        )
        if openSettings {
            PermissionGuidanceController.shared.present(
                pane: .appManagement,
                target: .ghostTile()
            )
        }
    }

    private func confirmCompatibilityWarnings(
        for app: ManagedAppItem,
        warnings: [AppCompatibility.Warning],
        onConfirm: @escaping @MainActor () -> Void
    ) {
        let confirmed = AlertPresenter.confirm(
            "Hide \(app.name)?",
            body: "May disable: \(warnings.map(\.impact).joined(separator: ", ")).",
            style: .warning,
            confirmButton: "Continue Anyway",
            tint: .standard
        )
        if confirmed {
            onConfirm()
        }
    }

    private func confirmUnsandbox(
        for app: ManagedAppItem,
        reason: String,
        onConfirm: @escaping @MainActor () -> Void
    ) {
        let confirmed = AlertPresenter.confirm(
            "Run \(app.name) unsandboxed?",
            body: reason,
            style: .warning,
            confirmButton: "Manage Anyway",
            cancelButton: "Cancel",
            tint: .caution
        )
        if confirmed {
            onConfirm()
        }
    }

    func setDockVisibility(_ app: ManagedAppItem, hidden: Bool) {
        guard let viewModel, app.isRunning else { return }
        if app.requiresReAdd {
            viewModel.showError(message: "\(app.name) was updated. Re-add it before changing Dock visibility.")
            return
        }
        viewModel.dockVisibilityController.send(bundleId: app.id, hidden: hidden)
        viewModel.scheduleRefresh(after: 0.5)
        viewModel.recordSponsorUse()
    }

    func activateManagedApp(_ app: ManagedAppItem) {
        guard let viewModel else { return }

        if let running = AppManager.runningApps(app.id).first {
            running.activate()
            viewModel.recordSponsorUse()
            return
        }

        let info = app.appInfo
        performAsync(for: app.id, showLoading: false) {
            try AppManager.launchManagedVisible(info)
        } onResult: { [weak viewModel] _ in
            viewModel?.recordSponsorUse()
            viewModel?.scheduleRefresh(after: 0.75)
        }
    }

    func revealAppInFinder(_ app: ManagedAppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.appPath)])
    }

    func handleAttentionNotificationClick(bundleId: String) {
        guard let viewModel,
              let app = viewModel.managedApp(bundleId: bundleId) else { return }

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
        guard let viewModel, !loading.contains(app.id) else { return }
        guard canRemove(app) else { return }
        guard ensureAppManagementPermission() else { return }

        let info = app.appInfo
        let wasRunning = app.isRunning
        let cli = viewModel.cliPath
        let refreshDelay: TimeInterval = wasRunning && !app.requiresReAdd ? Self.postOperationRefreshDelay : 0

        performAsync(for: app.id, refreshDelay: refreshDelay) {
            try AppOperations.removeApp(info, wasRunning: wasRunning)
        } onResult: { [weak viewModel] _ in
            viewModel?.recordSponsorUse()
        } onError: { [weak self, weak viewModel] error in
            if let gtError = error as? GhostTileError, case .appManagementDenied = gtError {
                self?.presentAppManagementPermissionAlert()
            } else {
                viewModel?.sudoCommand = ShellCommand.format(
                    executable: cli,
                    arguments: ["restore", info.bundleId],
                    requiresSudo: true
                )
            }
        }
    }

    private func canRemove(_ app: ManagedAppItem) -> Bool {
        guard app.requiresReAdd else { return true }
        return AlertPresenter.confirm(
            "Remove \(app.name)?",
            body: "It was updated; the old backup won't be restored.",
            style: .warning,
            confirmButton: "Remove",
            cancelButton: "Keep",
            tint: .destructive
        )
    }

    func hideByURL(_ url: URL) {
        guard let viewModel,
              let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier,
              let execURL = bundle.executableURL
        else { return }

        let appPath = url.path
        if let hiddenApp = Config.load().hidden[bundleId] {
            let needsReAdd = !GhosthidePatch.isApplied(to: execURL.path)
            if let existing = viewModel.apps.first(where: { $0.id == bundleId }) {
                if existing.requiresReAdd || needsReAdd {
                    readdManagedApp(existing)
                }
                return
            }

            guard needsReAdd else {
                return
            }

            let icon = NSWorkspace.shared.icon(forFile: appPath)
            let record = ManagedAppRecord(
                bundleId: bundleId,
                name: hiddenApp.name,
                appPath: appPath,
                binaryPath: execURL.path,
                managed: true,
                running: false,
                hiddenFromDock: true,
                pid: nil,
                isSIPProtected: AppManager.isSIPProtected(appPath),
                categoryIdentifier: bundle.infoDictionary?["LSApplicationCategoryType"] as? String,
                requiresReAdd: true
            )
            readdManagedApp(ManagedAppItem(record: record, icon: icon, category: .other))
            return
        }

        if AppManager.isSIPProtected(appPath) || AppManager.isAppleFirstParty(appPath) {
            viewModel
                .showError(
                    message: "\(bundle.infoDictionary?["CFBundleName"] as? String ?? bundleId) cannot be hidden."
                )
            return
        }

        if let existing = viewModel.apps.first(where: { $0.id == bundleId }) {
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
            // Cleanup runs inside the result Task so a re-entrant onResult can't race a stray cleanup.
            do {
                let result = try work()
                Task { @MainActor [weak self, weak viewModel] in
                    onResult(result)
                    self?.loading.remove(bundleId)
                    viewModel?.scheduleRefresh(after: refreshDelay)
                }
            } catch {
                Log.error("Operation failed for \(bundleId): \(error)")
                Task { @MainActor [weak self, weak viewModel] in
                    if let onError {
                        onError(error)
                    } else {
                        viewModel?.errorMessage = error.localizedDescription
                        viewModel?.showError = true
                    }
                    self?.loading.remove(bundleId)
                    viewModel?.scheduleRefresh(after: refreshDelay)
                }
            }
        }
    }
}
