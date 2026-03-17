import AppKit
import GhostTileCore

extension AppViewModel {
    func hideRunningApp(_ app: ManagedAppItem) {
        guard !loading.contains(app.id) else { return }

        if app.isSIPProtected {
            Log.info("Blocked: \(app.name) is SIP-protected")
            errorMessage = "\(app.name) is system-protected and cannot be hidden."
            showError = true
            return
        }
        Log.info("Hiding \(app.name) (\(app.id))")

        loading.insert(app.id)
        let bundleId = app.id
        let name = app.name
        let appPath = app.appPath
        let binaryPath = app.binaryPath
        let cliPath = cliPath

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try AppOperations.hideApp(
                    bundleId: bundleId,
                    name: name,
                    appPath: appPath,
                    binaryPath: binaryPath,
                    cliPath: cliPath
                )

                Task { @MainActor [weak self] in
                    switch result {
                    case .hidden:
                        self?.recordSponsorUse()
                    case .requiresSudo(let command):
                        self?.sudoCommand = command
                        self?.loading.remove(bundleId)
                    }
                }
            } catch {
                Log.error("Hide failed for \(name): \(error)")
                Task { @MainActor [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }

            Task { @MainActor [weak self] in
                self?.completeOperation(for: bundleId)
            }
        }
    }

    func showAppInDock(_ app: ManagedAppItem) {
        guard app.isRunning else { return }
        sendDockVisibilityNotification(bundleId: app.id, hidden: false)
        recordSponsorUse()
    }

    func hideAppFromDock(_ app: ManagedAppItem) {
        guard app.isRunning else { return }
        sendDockVisibilityNotification(bundleId: app.id, hidden: true)
        recordSponsorUse()
    }

    func managedApp(bundleId: String) -> ManagedAppItem? {
        hiddenApps.first(where: { $0.id == bundleId })
    }

    func activateManagedApp(_ app: ManagedAppItem) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first {
            running.activate()
            recordSponsorUse()
            return
        }

        let bundleId = app.id
        let name = app.name
        let appPath = app.appPath
        let binaryPath = app.binaryPath

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AppOperations.launchManagedVisible(
                    bundleId: bundleId,
                    name: name,
                    appPath: appPath,
                    binaryPath: binaryPath
                )
                Task { @MainActor [weak self] in
                    self?.recordSponsorUse()
                    self?.scheduleRefresh(after: 0.75)
                }
            } catch {
                Log.error("Launch failed for \(name): \(error)")
                Task { @MainActor [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }

    func revealAppInFinder(_ app: ManagedAppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.appPath)])
    }

    func handleAttentionNotificationClick(bundleId: String) {
        guard let app = managedApp(bundleId: bundleId) else { return }

        if app.isRunning, app.isHiddenFromDock {
            showAppInDock(app)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.activateManagedApp(app)
            }
            return
        }

        activateManagedApp(app)
    }

    func removeApp(_ app: ManagedAppItem) {
        guard !loading.contains(app.id) else { return }
        Log.info("Removing \(app.name) (\(app.id)) from managed apps")

        loading.insert(app.id)
        let wasRunning = app.isRunning
        let bundleId = app.id
        let appPath = app.appPath
        let binaryPath = app.binaryPath
        let name = app.name
        let cliPath = cliPath
        let refreshDelay: TimeInterval = wasRunning ? Self.postOperationRefreshDelay : 0

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AppOperations.removeApp(
                    bundleId: bundleId,
                    appPath: appPath,
                    binaryPath: binaryPath,
                    wasRunning: wasRunning
                )
                Task { @MainActor [weak self] in
                    self?.recordSponsorUse()
                }
            } catch {
                Log.error("Remove failed for \(name): \(error)")
                Task { @MainActor [weak self] in
                    self?.sudoCommand = "sudo \(cliPath) restore \(bundleId)"
                }
            }

            Task { @MainActor [weak self] in
                self?.completeOperation(for: bundleId, refreshDelay: refreshDelay)
            }
        }
    }

    func hideByURL(_ url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier,
              let execURL = bundle.executableURL
        else { return }

        let config = Config.load()
        if config.hidden[bundleId] != nil { return }

        let appPath = url.path
        if AppManager.isSIPProtected(appPath) || AppManager.isAppleFirstParty(appPath) {
            errorMessage = "\(bundle.infoDictionary?["CFBundleName"] as? String ?? bundleId) cannot be hidden."
            showError = true
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
            let item = ManagedAppItem(
                record: record,
                icon: icon,
                category: .other
            )
            hideRunningApp(item)
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
}
