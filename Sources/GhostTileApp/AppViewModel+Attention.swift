import Foundation
import GhostTileCore

extension AppViewModel {
    func syncAttentionObservers(bundleIds: Set<String>) {
        let dnc = DistributedNotificationCenter.default()

        for (bundleId, observer) in attentionObservers where !bundleIds.contains(bundleId) {
            dnc.removeObserver(observer)
            attentionObservers.removeValue(forKey: bundleId)
            lastAttentionNotificationAt.removeValue(forKey: bundleId)
        }

        for bundleId in bundleIds where attentionObservers[bundleId] == nil {
            let observer = dnc.addObserver(
                forName: ManagedAppNotifications.name(bundleId: bundleId, action: .attention),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAttentionSignal(bundleId: bundleId)
                }
            }
            attentionObservers[bundleId] = observer
        }
    }

    func handleAttentionSignal(bundleId: String) {
        guard let app = managedApp(bundleId: bundleId),
              app.isRunning,
              app.isHiddenFromDock
        else { return }

        let now = Date()
        if let lastShown = lastAttentionNotificationAt[bundleId],
           now.timeIntervalSince(lastShown) < Self.attentionNotificationCooldown
        {
            Log.debug("Skipping duplicate attention notification for \(bundleId)")
            return
        }

        lastAttentionNotificationAt[bundleId] = now
        Log.info("Delivering attention notification for \(bundleId)")
        AttentionNotificationController.shared.deliverNotification(
            bundleId: bundleId,
            appName: app.name
        )
    }
}
