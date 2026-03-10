import Foundation

public enum ManagedAppNotificationAction: String {
    case hide
    case show
    case toggle
}

public enum ManagedAppNotifications {
    public static func name(
        bundleId: String,
        action: ManagedAppNotificationAction
    ) -> Notification.Name {
        Notification.Name("\(bundleId).ghosttile.\(action.rawValue)")
    }

    public static func post(
        bundleId: String,
        action: ManagedAppNotificationAction
    ) {
        let notificationName = name(bundleId: bundleId, action: action)
        Log.info("Posting distributed notification: \(notificationName.rawValue)")
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
