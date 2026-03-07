import AppKit
import GhostTileCore
import LSAppCategory
import os.log

class AppViewModel: ObservableObject {
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
    }

    @Published var apps: [AppItem] = []
    @Published var loading: Set<String> = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var dockVisible = false

    var hiddenCount: Int { apps.filter(\.isHidden).count }
    var hiddenApps: [AppItem] { apps.filter(\.isHidden) }
    var visibleApps: [AppItem] {
        apps.filter { !$0.isHidden && !$0.isSIPProtected && !$0.id.hasPrefix("com.apple.") }
    }

    private var observers: [NSObjectProtocol] = []
    private var configFileMonitor: DispatchSourceFileSystemObject?

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
        configFileMonitor?.cancel()
    }

    private func watchConfigFile() {
        // Ensure config dir exists
        try? FileManager.default.createDirectory(
            atPath: Config.configDir, withIntermediateDirectories: true)

        // Watch the config directory for changes (file may be recreated)
        let dirFD = open(Config.configDir, O_EVTONLY)
        guard dirFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD, eventMask: .write, queue: .main
        )
        source.setEventHandler { [weak self] in
            Log.info("Config file changed on disk, refreshing")
            self?.refresh()
        }
        source.setCancelHandler { close(dirFD) }
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
                isRunning: true
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
                isRunning: false
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

            DispatchQueue.main.async { self?.loading.remove(app.id) }
            Thread.sleep(forTimeInterval: 1.5)
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    // MARK: - Toggle managed app visibility via distributed notification

    func toggleAppVisibility(_ app: AppItem) {
        guard app.isRunning else { return }
        let name = "\(app.id).ghosttile.toggle"
        Log.info("Sending toggle notification: \(name)")
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(name), object: nil, userInfo: nil,
            deliverImmediately: true
        )
    }

    // MARK: - Remove managed app (restore + remove from config)

    func removeApp(_ app: AppItem) {
        guard !loading.contains(app.id) else { return }
        Log.info("Removing \(app.name) (\(app.id)) from managed apps")

        loading.insert(app.id)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                if app.isRunning {
                    try AppManager.quit(app.id)
                }
                try AppManager.restoreBinary(app.id, binaryPath: app.binaryPath, appPath: app.appPath)
                try Config.removeHidden(app.id)
                try AppManager.launchNormal(app.appPath)
            } catch {
                Log.error("Remove failed for \(app.name): \(error)")
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }

            DispatchQueue.main.async { self?.loading.remove(app.id) }
            Thread.sleep(forTimeInterval: 1.5)
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    /// Hide an app by its file URL (dropped from Finder/Dock)
    func hideByURL(_ url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier
        else { return }

        if let existing = apps.first(where: { $0.id == bundleId }) {
            if !existing.isHidden && !existing.isSIPProtected {
                hideRunningApp(existing)
            }
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

            DispatchQueue.main.async { self?.loading.remove(bundleId) }
            Thread.sleep(forTimeInterval: 1.5)
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    func reapplyHidden() {
        let config = Config.load()
        guard !config.hidden.isEmpty else { return }
        Log.info("Reapplying hidden state for \(config.hidden.count) app(s)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for (bundleId, hiddenApp) in config.hidden {
                let running = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleId)
                guard let proc = running.first,
                      proc.activationPolicy == .regular
                else { continue }

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

                DispatchQueue.main.async { self?.loading.remove(bundleId) }
            }

            Thread.sleep(forTimeInterval: 1.5)
            DispatchQueue.main.async { self?.refresh() }
        }
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
            Log.info("Blocked: \(name) has hardened runtime and needs sudo")
            throw GhostTileError(
                "\(name) has hardened runtime and requires sudo to re-sign. Install the CLI in Settings, then run:\n\nsudo ghosttile hide \(bundleId)"
            )
        }
        let dylibPath = try Dylib.ensureCompiled()
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
