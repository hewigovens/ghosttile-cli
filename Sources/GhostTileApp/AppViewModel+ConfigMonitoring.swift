import AppKit
import GhostTileCore
import LSAppCategory

extension AppViewModel {
    func watchConfigFile() {
        try? FileManager.default.createDirectory(
            atPath: Config.configDir, withIntermediateDirectories: true)
        watchConfigDirectory()
        refreshConfigFileMonitor()
    }

    func watchConfigDirectory() {
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

    func refreshConfigFileMonitor() {
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
        syncAttentionObservers(bundleIds: Set(config.hidden.keys))
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
}
