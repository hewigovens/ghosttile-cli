import AppKit
import Foundation

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
            records: sortedRecords(records),
            managedBundleIds: Set(config.hidden.keys)
        )
    }

    static func sortedRecords(_ records: [ManagedAppRecord]) -> [ManagedAppRecord] {
        records.sorted(by: recordSort)
    }

    private static func recordSort(_ lhs: ManagedAppRecord, _ rhs: ManagedAppRecord) -> Bool {
        let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }

        let bundleOrder = lhs.bundleId.localizedStandardCompare(rhs.bundleId)
        if bundleOrder != .orderedSame {
            return bundleOrder == .orderedAscending
        }

        return lhs.appPath.localizedStandardCompare(rhs.appPath) == .orderedAscending
    }
}
