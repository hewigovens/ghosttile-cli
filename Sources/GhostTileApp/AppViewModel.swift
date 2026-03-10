import AppKit
import GhostTileCore
import LSAppCategory
import os.log

class AppViewModel: ObservableObject {
    private static let postOperationRefreshDelay: TimeInterval = 1.5
    private static let startupNotificationProbeDelay: TimeInterval = 0.75

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

    private var observers: [NSObjectProtocol] = []
    private var configDirectoryMonitor: DispatchSourceFileSystemObject?
    private var configFileMonitor: DispatchSourceFileSystemObject?

    var cliPath: String {
        let installed = "/usr/local/bin/ghosttile"
        if FileManager.default.fileExists(atPath: installed) { return installed }
        let execURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let bundled = execURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/ghosttile-cli").path
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
        configDirectoryMonitor?.cancel()
        configFileMonitor?.cancel()
    }

    private func watchConfigFile() {
        try? FileManager.default.createDirectory(
            atPath: Config.configDir, withIntermediateDirectories: true)
        watchConfigDirectory()
        refreshConfigFileMonitor()
    }

    private func watchConfigDirectory() {
        configDirectoryMonitor?.cancel()

        let dirFD = open(Config.configDir, O_EVTONLY)
        guard dirFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD, eventMask: [.write, .rename, .delete], queue: .main
        )
        source.setEventHandler { [weak self] in
            Log.info("Config directory changed on disk, updating watcher")
            self?.refreshConfigFileMonitor()
            self?.refresh()
        }
        source.setCancelHandler { close(dirFD) }
        source.resume()
        configDirectoryMonitor = source
    }

    private func refreshConfigFileMonitor() {
        configFileMonitor?.cancel()
        configFileMonitor = nil

        guard FileManager.default.fileExists(atPath: Config.configPath) else { return }

        let fileFD = open(Config.configPath, O_EVTONLY)
        guard fileFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileFD, eventMask: [.write, .rename, .delete], queue: .main
        )
        source.setEventHandler { [weak self] in
            Log.info("Config file changed on disk, refreshing")
            self?.refresh()
            self?.refreshConfigFileMonitor()
        }
        source.setCancelHandler { close(fileFD) }
        source.resume()
        configFileMonitor = source
    }

    func refresh() {
        let config = Config.load()
        let runningApps = NSWorkspace.shared.runningApplications
        let runningIds = Set(runningApps.compactMap(\.bundleIdentifier))

        let running = runningApps
            .filter { app in
                guard let id = app.bundleIdentifier else { return false }
                if id == "dev.hewig.ghosttile" { return false }
                return app.activationPolicy == .regular || config.hidden[id] != nil
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        var result: [AppItem] = running.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                let bundleURL = app.bundleURL,
                let bundle = Bundle(url: bundleURL),
                let execURL = bundle.executableURL
            else { return nil }

            let appPath = bundleURL.path
            let categoryStr = bundle.infoDictionary?["LSApplicationCategoryType"] as? String
            return AppItem(
                id: bundleId,
                name: app.localizedName ?? bundleId,
                icon: app.icon ?? NSImage(size: NSSize(width: 20, height: 20)),
                appPath: appPath,
                binaryPath: execURL.path,
                category: AppCategory(string: categoryStr),
                isHidden: config.hidden[bundleId] != nil,
                isSIPProtected: AppManager.isSIPProtected(appPath),
                isRunning: true,
                isHiddenFromDock: app.activationPolicy == .accessory
            )
        }

        for (bundleId, hiddenApp) in config.hidden where !runningIds.contains(bundleId) {
            let bundleURL = URL(fileURLWithPath: hiddenApp.appPath)
            let bundle = Bundle(url: bundleURL)
            let icon: NSImage
            if let bundle = bundle {
                icon = NSWorkspace.shared.icon(forFile: bundle.bundlePath)
            } else {
                icon = NSImage(size: NSSize(width: 20, height: 20))
            }
            let categoryStr = bundle?.infoDictionary?["LSApplicationCategoryType"] as? String
            result.append(AppItem(
                id: bundleId,
                name: hiddenApp.name,
                icon: icon,
                appPath: hiddenApp.appPath,
                binaryPath: hiddenApp.binaryPath,
                category: AppCategory(string: categoryStr),
                isHidden: true,
                isSIPProtected: false,
                isRunning: false,
                isHiddenFromDock: true
            ))
        }

        apps = result
    }

    // MARK: - Hide a running app

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

    // MARK: - Show/Hide managed app via distributed notification

    func showAppInDock(_ app: AppItem) {
        guard app.isRunning else { return }
        sendDockVisibilityNotification(bundleId: app.id, hidden: false)
    }

    func hideAppFromDock(_ app: AppItem) {
        guard app.isRunning else { return }
        sendDockVisibilityNotification(bundleId: app.id, hidden: true)
    }

    // MARK: - Remove managed app (restore + remove from config)

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

    /// Hide an app by its file URL (dropped from Finder/Dock)
    func hideByURL(_ url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier,
              let execURL = bundle.executableURL
        else { return }

        // Already managed
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
            // App not running — build AppItem and hide
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

    // MARK: - Auto-hide

    private func autoHideIfNeeded(_ bundleId: String) {
        let autoHide = UserDefaults.standard.object(forKey: "autoHideOnLaunch") as? Bool ?? true
        guard autoHide else { return }

        let config = Config.load()
        guard let hiddenApp = config.hidden[bundleId] else { return }
        Log.info("Auto-hiding relaunched app: \(hiddenApp.name) (\(bundleId))")

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            [weak self] in
            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            guard let proc = running.first, proc.activationPolicy == .regular else { return }

            DispatchQueue.main.async { self?.loading.insert(bundleId) }

            do {
                try self?.hideApp(
                    bundleId: bundleId, name: hiddenApp.name,
                    appPath: hiddenApp.appPath, binaryPath: hiddenApp.binaryPath
                )
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }

            self?.completeOperation(for: bundleId)
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

    // MARK: - Core hide logic

    private func hideApp(bundleId: String, name: String, appPath: String, binaryPath: String)
        throws
    {
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
        let dylibPath = try Dylib.ensureDylib()
        if try AppManager.needsPreparation(info) {
            try AppManager.prepare(info)
        }
        try AppManager.quit(bundleId)
        try AppManager.launchHidden(info, dylibPath: dylibPath)
        try Config.addHidden(
            bundleId,
            app: HiddenApp(
                name: name, appPath: appPath,
                binaryPath: binaryPath, prepared: true))
    }

    private func completeOperation(for bundleId: String, refreshDelay: TimeInterval = postOperationRefreshDelay) {
        DispatchQueue.main.async { [weak self] in
            self?.loading.remove(bundleId)
        }
        scheduleRefresh(after: refreshDelay)
    }

    private func reapplyHiddenAtStartup(bundleId: String, hiddenApp: HiddenApp) {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleId)
        guard let process = running.first else { return }

        if process.activationPolicy == .accessory {
            Log.info("\(hiddenApp.name) is already hidden on startup")
            return
        }

        Log.info("Probing \(hiddenApp.name) with hide notification on startup")
        sendDockVisibilityNotification(bundleId: bundleId, hidden: true, refreshDelay: 0)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + Self.startupNotificationProbeDelay
        ) { [weak self] in
            guard let self else { return }

            let updated = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            guard let current = updated.first else {
                self.scheduleRefresh(after: 0)
                return
            }

            if current.activationPolicy == .accessory {
                Log.info("\(hiddenApp.name) responded to startup hide notification")
                self.scheduleRefresh(after: 0)
                return
            }

            Log.info("\(hiddenApp.name) still visible on startup, reapplying injection")
            DispatchQueue.main.async {
                self.loading.insert(bundleId)
            }

            do {
                try self.hideApp(
                    bundleId: bundleId,
                    name: hiddenApp.name,
                    appPath: hiddenApp.appPath,
                    binaryPath: hiddenApp.binaryPath
                )
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }

            self.completeOperation(for: bundleId)
        }
    }

    private func sendDockVisibilityNotification(
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

    private func scheduleRefresh(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.refresh()
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
