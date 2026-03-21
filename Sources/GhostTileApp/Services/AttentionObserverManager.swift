import Foundation
import GhostTileCore

@MainActor
final class AttentionObserverManager {
    private static let cooldown: TimeInterval = 10

    private var observers: [String: NSObjectProtocol] = [:]
    private var lastNotificationAt: [String: Date] = [:]
    private weak var viewModel: AppViewModel?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    deinit {
        let dnc = DistributedNotificationCenter.default()
        for observer in observers.values {
            dnc.removeObserver(observer)
        }
    }

    func sync(bundleIds: Set<String>) {
        let dnc = DistributedNotificationCenter.default()

        for (bundleId, observer) in observers where !bundleIds.contains(bundleId) {
            dnc.removeObserver(observer)
            observers.removeValue(forKey: bundleId)
            lastNotificationAt.removeValue(forKey: bundleId)
        }

        for bundleId in bundleIds where observers[bundleId] == nil {
            let observer = dnc.addObserver(
                forName: ManagedAppNotifications.name(bundleId: bundleId, action: .attention),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSignal(bundleId: bundleId)
                }
            }
            observers[bundleId] = observer
        }
    }

    func removeAll() {
        let dnc = DistributedNotificationCenter.default()
        for observer in observers.values {
            dnc.removeObserver(observer)
        }
        observers.removeAll()
        lastNotificationAt.removeAll()
    }

    private func handleSignal(bundleId: String) {
        guard let app = viewModel?.managedApp(bundleId: bundleId),
              app.isRunning,
              app.isHiddenFromDock
        else { return }

        let now = Date()
        if let lastShown = lastNotificationAt[bundleId],
           now.timeIntervalSince(lastShown) < Self.cooldown {
            Log.debug("Skipping duplicate attention notification for \(bundleId)")
            return
        }

        lastNotificationAt[bundleId] = now
        Log.info("Delivering attention notification for \(bundleId)")
        AttentionNotificationController.shared.deliverNotification(
            bundleId: bundleId,
            appName: app.name
        )
    }
}
