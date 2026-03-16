import AppKit
import GhostTileCore

extension AppViewModel {
    func hideRunningApp(_ app: AppItem) {
        guard !loading.contains(app.id) else { return }

        if app.isSIPProtected {
            Log.info("Blocked: \(app.name) is SIP-protected")
            errorMessage = "\(app.name) is system-protected and cannot be hidden."
            showError = true
            return
        }
        Log.info("Hiding \(app.name) (\(app.id))")

        loading.insert(app.id)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.hideApp(
                    bundleId: app.id, name: app.name,
                    appPath: app.appPath, binaryPath: app.binaryPath
                )
                self?.recordSponsorUse()
            } catch {
                Log.error("Hide failed for \(app.name): \(error)")
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }

            self?.completeOperation(for: app.id)
        }
    }

    func showAppInDock(_ app: AppItem) {
        guard app.isRunning else { return }
        sendDockVisibilityNotification(bundleId: app.id, hidden: false)
        recordSponsorUse()
    }

    func hideAppFromDock(_ app: AppItem) {
        guard app.isRunning else { return }
        sendDockVisibilityNotification(bundleId: app.id, hidden: true)
        recordSponsorUse()
    }

    func managedApp(bundleId: String) -> AppItem? {
        hiddenApps.first(where: { $0.id == bundleId })
    }

    func activateManagedApp(_ app: AppItem) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first {
            running.activate()
            recordSponsorUse()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let info = AppInfo(
                    bundleId: app.id,
                    name: app.name,
                    appPath: app.appPath,
                    binaryPath: app.binaryPath
                )
                try AppManager.launchManagedVisible(info)
                self?.recordSponsorUse()
                self?.scheduleRefresh(after: 0.75)
            } catch {
                Log.error("Launch failed for \(app.name): \(error)")
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }

    func revealAppInFinder(_ app: AppItem) {
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

    func removeApp(_ app: AppItem) {
        guard !loading.contains(app.id) else { return }
        Log.info("Removing \(app.name) (\(app.id)) from managed apps")

        loading.insert(app.id)
        let wasRunning = app.isRunning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                if wasRunning {
                    try AppManager.quit(app.id)
                }
                try AppManager.restoreBinary(app.id, binaryPath: app.binaryPath, appPath: app.appPath)
                try Config.removeHidden(app.id)
                if wasRunning {
                    try AppManager.launchNormal(app.appPath)
                }
                self?.recordSponsorUse()
            } catch {
                Log.error("Remove failed for \(app.name): \(error)")
                DispatchQueue.main.async {
                    self?.sudoCommand = "sudo \(self?.cliPath ?? "ghosttile") restore \(app.id)"
                }
            }

            self?.completeOperation(
                for: app.id,
                refreshDelay: wasRunning ? Self.postOperationRefreshDelay : 0
            )
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
            let item = AppItem(
                id: bundleId, name: name, icon: icon,
                appPath: appPath, binaryPath: execURL.path,
                category: .other, isHidden: false,
                isSIPProtected: false, isRunning: false,
                isHiddenFromDock: false
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
