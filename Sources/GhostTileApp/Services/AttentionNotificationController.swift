import Foundation
import GhostTileCore
import UserNotifications

final class AttentionNotificationController: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AttentionNotificationController()

    private let center = UNUserNotificationCenter.current()
    private weak var viewModel: AppViewModel?

    override private init() {
        super.init()
    }

    func start(viewModel: AppViewModel) {
        self.viewModel = viewModel
        center.delegate = self
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
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
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

}
