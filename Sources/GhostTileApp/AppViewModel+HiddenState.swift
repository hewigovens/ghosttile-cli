import AppKit
import GhostTileCore

extension AppViewModel {
    func autoHideIfNeeded(_ bundleId: String) {
        let autoHide = UserDefaults.standard.object(forKey: "autoHideOnLaunch") as? Bool ?? true
        guard autoHide else { return }

        let config = Config.load()
        guard let hiddenApp = config.hidden[bundleId] else { return }
        Log.info("Sending auto-hide notification for launched managed app: \(hiddenApp.name) (\(bundleId))")

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            [weak self] in
            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            guard let proc = running.first, proc.activationPolicy == .regular else { return }
            self?.sendDockVisibilityNotification(bundleId: bundleId, hidden: true, refreshDelay: 0)
        }
    }

    func reapplyHidden() {
        let config = Config.load()
        guard !config.hidden.isEmpty else { return }
        Log.info("Reapplying hidden state for \(config.hidden.count) app(s)")

        for (bundleId, hiddenApp) in config.hidden {
            reapplyHiddenAtStartup(bundleId: bundleId, hiddenApp: hiddenApp)
        }

        scheduleRefresh(after: 0.5)
    }

    func hideApp(bundleId: String, name: String, appPath: String, binaryPath: String) throws {
        Log.info("Hiding app: \(name) (\(bundleId))")
        if AppManager.isAppleFirstParty(appPath) {
            Log.info("Blocked: \(name) is Apple first-party")
            throw GhostTileError(
                "\(name) is an Apple system app and cannot be hidden."
            )
        }
        let info = AppInfo(
            bundleId: bundleId, name: name,
            appPath: appPath, binaryPath: binaryPath)
        if try AppManager.needsSudo(info) {
            Log.info("Blocked: \(name) needs manual step via CLI")
            DispatchQueue.main.async { [weak self] in
                self?.sudoCommand = "sudo \(self?.cliPath ?? "ghosttile") manage \(bundleId)"
                self?.loading.remove(bundleId)
            }
            return
        }
        if try AppManager.needsPreparation(info) {
            try AppManager.prepare(info)
        }
        try AppManager.quit(bundleId)
        try AppManager.launchHidden(info)
        try Config.addHidden(
            bundleId,
            app: HiddenApp(
                name: name, appPath: appPath,
                binaryPath: binaryPath, prepared: true))
    }

    func completeOperation(for bundleId: String, refreshDelay: TimeInterval = postOperationRefreshDelay) {
        DispatchQueue.main.async { [weak self] in
            self?.loading.remove(bundleId)
        }
        scheduleRefresh(after: refreshDelay)
    }

    func reapplyHiddenAtStartup(bundleId: String, hiddenApp: HiddenApp) {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleId)
        guard let process = running.first else { return }

        if process.activationPolicy == .accessory {
            Log.info("\(hiddenApp.name) is already hidden on startup")
            return
        }

        Log.info("Sending hide notification to \(hiddenApp.name) on startup")
        sendDockVisibilityNotification(bundleId: bundleId, hidden: true, refreshDelay: 0)
    }

    func sendDockVisibilityNotification(
        bundleId: String,
        hidden: Bool,
        refreshDelay: TimeInterval = 0.5
    ) {
        ManagedAppNotifications.post(
            bundleId: bundleId,
            action: hidden ? .hide : .show
        )
        scheduleRefresh(after: refreshDelay)
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
}
