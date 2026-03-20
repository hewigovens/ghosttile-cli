import Foundation
import GhostTileCore
import UserNotifications

final class AttentionNotificationController: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AttentionNotificationController()

    private let center = UNUserNotificationCenter.current()
    private weak var viewModel: AppViewModel?
#if DEBUG
    private var didDeliverDebugStartupNotification = false
#endif

    private override init() {
        super.init()
    }

    func start(viewModel: AppViewModel) {
        self.viewModel = viewModel
        center.delegate = self
#if DEBUG
        deliverDebugStartupNotificationIfNeeded()
#endif
    }

    func deliverNotification(bundleId: String, appName: String) {
        Task {
            guard await ensureAuthorization() else {
                Log.info("Notifications not authorized; skipping attention notification for \(bundleId)")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "\(appName) needs attention"
            content.body = "Click to reveal and activate it in GhostTile."
            content.userInfo = ["bundleId": bundleId]
            content.threadIdentifier = "ghosttile.attention"

            let request = UNNotificationRequest(
                identifier: "ghosttile.attention.\(bundleId)",
                content: content,
                trigger: nil
            )

            do {
                try await center.add(request)
            } catch {
                Log.error("Failed to deliver attention notification for \(bundleId): \(error)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let bundleId = response.notification.request.content.userInfo["bundleId"] as? String else {
            return
        }

        await MainActor.run {
            viewModel?.handleAttentionNotificationClick(bundleId: bundleId)
        }
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge])
            } catch {
                Log.error("Notification authorization request failed: \(error)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

#if DEBUG
    private func deliverDebugStartupNotificationIfNeeded() {
        guard !didDeliverDebugStartupNotification else { return }
        didDeliverDebugStartupNotification = true

        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)

            guard await ensureAuthorization() else {
                Log.info("Notifications not authorized; skipping debug startup notification")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "GhostTile started"
            content.body = "Debug notification for icon verification."
            content.threadIdentifier = "ghosttile.debug"

            let request = UNNotificationRequest(
                identifier: "ghosttile.debug.startup",
                content: content,
                trigger: nil
            )

            do {
                Log.debug("Delivering debug startup notification")
                try await center.add(request)
            } catch {
                Log.error("Failed to deliver debug startup notification: \(error)")
            }
        }
    }
#endif
}
