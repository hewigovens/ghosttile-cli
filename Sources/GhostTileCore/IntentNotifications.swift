import Foundation

public enum IntentRequestAction: String, Sendable {
    case hide
    case show
    case focus
    case openWindow
}

public enum IntentNotifications {
    public static let name = Notification.Name("dev.hewig.ghosttile.intent.request")
    public static let actionKey = "action"
    public static let bundleIdKey = "bundleId"

    public struct Request: Equatable, Sendable {
        public let action: IntentRequestAction
        public let bundleId: String?

        public init(action: IntentRequestAction, bundleId: String? = nil) {
            self.action = action
            self.bundleId = bundleId
        }
    }

    public static func userInfo(for request: Request) -> [String: String] {
        var info = [actionKey: request.action.rawValue]
        if let bundleId = request.bundleId { info[bundleIdKey] = bundleId }
        return info
    }

    public static func parse(_ notification: Notification) -> Request? {
        guard let info = notification.userInfo as? [String: String],
              let raw = info[actionKey],
              let action = IntentRequestAction(rawValue: raw)
        else { return nil }
        return Request(action: action, bundleId: info[bundleIdKey])
    }

    public static func post(action: IntentRequestAction, bundleId: String? = nil) {
        let request = Request(action: action, bundleId: bundleId)
        DistributedNotificationCenter.default().postNotificationName(
            name,
            object: nil,
            userInfo: userInfo(for: request),
            deliverImmediately: true
        )
    }
}
