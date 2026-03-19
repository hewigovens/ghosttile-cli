import AppKit
import GhostTileCore

extension AppViewModel {
    func hideRunningApp(_ app: ManagedAppItem) {
        guard !loading.contains(app.id) else { return }

        if app.isSIPProtected {
            showError(message: "\(app.name) is system-protected and cannot be hidden.")
            return
        }

        let info = app.appInfo
        let cli = cliPath
        performAsync(for: app.id) {
            try AppOperations.hideApp(info, cliPath: cli)
        } onResult: { [weak self] result in
            switch result {
            case .hidden:
                self?.recordSponsorUse()
            case .requiresSudo(let command):
                self?.sudoCommand = command
                self?.loading.remove(info.bundleId)
            }
        }
    }

    func setDockVisibility(_ app: ManagedAppItem, hidden: Bool) {
        guard app.isRunning else { return }
        sendDockVisibilityNotification(bundleId: app.id, hidden: hidden)
        recordSponsorUse()
    }

    func managedApp(bundleId: String) -> ManagedAppItem? {
        hiddenApps.first(where: { $0.id == bundleId })
    }

    func activateManagedApp(_ app: ManagedAppItem) {
        if let running = AppManager.runningApps(app.id).first {
            running.activate()
            recordSponsorUse()
            return
        }

        let info = app.appInfo
        performAsync(for: app.id, showLoading: false) {
            try AppManager.launchManagedVisible(info)
        } onResult: { [weak self] _ in
            self?.recordSponsorUse()
            self?.scheduleRefresh(after: 0.75)
        }
    }

    func revealAppInFinder(_ app: ManagedAppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.appPath)])
    }

    func handleAttentionNotificationClick(bundleId: String) {
        guard let app = managedApp(bundleId: bundleId) else { return }

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
        guard !loading.contains(app.id) else { return }

        let info = app.appInfo
        let wasRunning = app.isRunning
        let cli = cliPath
        let refreshDelay: TimeInterval = wasRunning ? Self.postOperationRefreshDelay : 0

        performAsync(for: app.id, refreshDelay: refreshDelay) {
            try AppOperations.removeApp(info, wasRunning: wasRunning)
        } onResult: { [weak self] _ in
            self?.recordSponsorUse()
        } onError: { [weak self] _ in
            self?.sudoCommand = "sudo \(cli) restore \(info.bundleId)"
        }
    }

    func hideByURL(_ url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier,
              let execURL = bundle.executableURL
        else { return }

        if Config.load().hidden[bundleId] != nil { return }

        let appPath = url.path
        if AppManager.isSIPProtected(appPath) || AppManager.isAppleFirstParty(appPath) {
            showError(message: "\(bundle.infoDictionary?["CFBundleName"] as? String ?? bundleId) cannot be hidden.")
            return
        }

        if let existing = apps.first(where: { $0.id == bundleId }) {
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

    // MARK: - Helpers

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func performAsync<T>(
        for bundleId: String,
        showLoading: Bool = true,
        refreshDelay: TimeInterval = 1.5,
        work: @escaping () throws -> T,
        onResult: @escaping @MainActor (T) -> Void = { _ in },
        onError: (@MainActor (Error) -> Void)? = nil
    ) {
        if showLoading { loading.insert(bundleId) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try work()
                Task { @MainActor in
                    onResult(result)
                }
            } catch {
                Log.error("Operation failed for \(bundleId): \(error)")
                Task { @MainActor [weak self] in
                    if let onError {
                        onError(error)
                    } else {
                        self?.errorMessage = error.localizedDescription
                        self?.showError = true
                    }
                }
            }
            Task { @MainActor [weak self] in
                self?.completeOperation(for: bundleId, refreshDelay: refreshDelay)
            }
        }
    }
}
