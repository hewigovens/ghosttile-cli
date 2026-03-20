import AppKit
import GhostTileCore
import LSAppCategory

struct ManagedAppsSnapshot {
    let apps: [ManagedAppItem]
    let managedBundleIds: Set<String>
}

enum ManagedAppsSnapshotBuilder {
    static func makeSnapshot() -> ManagedAppsSnapshot {
        let snapshot = ManagedAppStateReader.makeSnapshot()
        let items = snapshot.records.map { record in
            let bundleURL = URL(fileURLWithPath: record.appPath)
            let bundle = Bundle(url: bundleURL)
            let icon =
                bundle.map { NSWorkspace.shared.icon(forFile: $0.bundlePath) }
                ?? NSImage(size: NSSize(width: 20, height: 20))
            return ManagedAppItem(
                record: record,
                icon: icon,
                category: AppCategory(string: record.categoryIdentifier)
            )
        }

        return ManagedAppsSnapshot(
            apps: items,
            managedBundleIds: snapshot.managedBundleIds
        )
    }
}
