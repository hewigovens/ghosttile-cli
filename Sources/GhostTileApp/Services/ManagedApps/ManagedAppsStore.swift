import Combine
import Foundation

@MainActor
final class ManagedAppsStore: ObservableObject {
    @Published private(set) var apps: [ManagedAppItem] = []
    @Published private(set) var managedBundleIds: Set<String> = []

    private var configWatcher: ConfigWatcher?

    func startWatching() {
        guard configWatcher == nil else { return }

        configWatcher = ConfigWatcher(
            onDirectoryChange: { [weak self] in
                self?.refresh()
            },
            onFileChange: { [weak self] in
                self?.refresh()
            }
        )
        configWatcher?.start()
    }

    func stopWatching() {
        configWatcher?.cancel()
        configWatcher = nil
    }

    func refresh() {
        let snapshot = ManagedAppsSnapshotBuilder.makeSnapshot()
        apps = snapshot.apps
        managedBundleIds = snapshot.managedBundleIds
    }
}
