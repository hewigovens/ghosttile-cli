import AppKit
import Foundation

public struct ManagedAppRecord: Identifiable, Encodable, Sendable {
    public let bundleId: String
    public let name: String
    public let appPath: String
    public let binaryPath: String
    public let managed: Bool
    public let running: Bool
    public let hiddenFromDock: Bool
    public let pid: pid_t?
    public let isSIPProtected: Bool
    public let categoryIdentifier: String?

    public var id: String {
        bundleId
    }

    public init(
        bundleId: String,
        name: String,
        appPath: String,
        binaryPath: String,
        managed: Bool,
        running: Bool,
        hiddenFromDock: Bool,
        pid: pid_t?,
        isSIPProtected: Bool,
        categoryIdentifier: String?
    ) {
        self.bundleId = bundleId
        self.name = name
        self.appPath = appPath
        self.binaryPath = binaryPath
        self.managed = managed
        self.running = running
        self.hiddenFromDock = hiddenFromDock
        self.pid = pid
        self.isSIPProtected = isSIPProtected
        self.categoryIdentifier = categoryIdentifier
    }
}

public struct ManagedAppStateSnapshot: Sendable {
    public let records: [ManagedAppRecord]
    public let managedBundleIds: Set<String>

    public init(records: [ManagedAppRecord], managedBundleIds: Set<String>) {
        self.records = records
        self.managedBundleIds = managedBundleIds
    }
}

public enum ManagedAppStateReader {
    public static func makeSnapshot() -> ManagedAppStateSnapshot {
        let config = Config.load()
        let runningApps = NSWorkspace.shared.runningApplications
        let runningIds = Set(runningApps.compactMap(\.bundleIdentifier))

        let visibleRunningApps = runningApps
            .filter { app in
                guard let bundleId = app.bundleIdentifier else { return false }
                if bundleId == "dev.hewig.ghosttile" { return false }
                return app.activationPolicy == .regular || config.hidden[bundleId] != nil
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        var records: [ManagedAppRecord] = visibleRunningApps.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  let bundleURL = app.bundleURL,
                  let bundle = Bundle(url: bundleURL),
                  let executableURL = bundle.executableURL
            else { return nil }

            let appPath = bundleURL.path
            return ManagedAppRecord(
                bundleId: bundleId,
                name: app.localizedName ?? bundleId,
                appPath: appPath,
                binaryPath: executableURL.path,
                managed: config.hidden[bundleId] != nil,
                running: true,
                hiddenFromDock: app.activationPolicy == .accessory,
                pid: app.processIdentifier,
                isSIPProtected: AppManager.isSIPProtected(appPath),
                categoryIdentifier: bundle.infoDictionary?["LSApplicationCategoryType"] as? String
            )
        }

        for (bundleId, hiddenApp) in config.hidden where !runningIds.contains(bundleId) {
            let bundleURL = URL(fileURLWithPath: hiddenApp.appPath)
            let bundle = Bundle(url: bundleURL)
            records.append(
                ManagedAppRecord(
                    bundleId: bundleId,
                    name: hiddenApp.name,
                    appPath: hiddenApp.appPath,
                    binaryPath: hiddenApp.binaryPath,
                    managed: true,
                    running: false,
                    hiddenFromDock: true,
                    pid: nil,
                    isSIPProtected: false,
                    categoryIdentifier: bundle?.infoDictionary?["LSApplicationCategoryType"] as? String
                )
            )
        }

        return ManagedAppStateSnapshot(
            records: records,
            managedBundleIds: Set(config.hidden.keys)
        )
    }
}
