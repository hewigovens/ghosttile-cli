import Foundation
@testable import GhostTileCore
import Testing

@Suite("IntentNotifications")
struct IntentNotificationsTests {
    @Test func userInfoRoundTripWithBundleId() {
        let request = IntentNotifications.Request(action: .hide, bundleId: "com.example.app")
        let info = IntentNotifications.userInfo(for: request)
        let notification = Notification(name: IntentNotifications.name, userInfo: info)

        #expect(IntentNotifications.parse(notification) == request)
    }

    @Test func userInfoRoundTripWithoutBundleId() {
        let request = IntentNotifications.Request(action: .openWindow)
        let info = IntentNotifications.userInfo(for: request)
        let notification = Notification(name: IntentNotifications.name, userInfo: info)

        let parsed = IntentNotifications.parse(notification)
        #expect(parsed?.action == .openWindow)
        #expect(parsed?.bundleId == nil)
    }

    @Test func parseReturnsNilWhenActionMissing() {
        let notification = Notification(
            name: IntentNotifications.name,
            userInfo: [IntentNotifications.bundleIdKey: "com.example.app"]
        )
        #expect(IntentNotifications.parse(notification) == nil)
    }

    @Test func parseReturnsNilForUnknownAction() {
        let notification = Notification(
            name: IntentNotifications.name,
            userInfo: [IntentNotifications.actionKey: "explode"]
        )
        #expect(IntentNotifications.parse(notification) == nil)
    }

    @Test func parseReturnsNilWhenUserInfoIsAbsent() {
        let notification = Notification(name: IntentNotifications.name)
        #expect(IntentNotifications.parse(notification) == nil)
    }

    @Test func allActionsRoundTrip() {
        for action in [IntentRequestAction.hide, .show, .focus, .openWindow] {
            let request = IntentNotifications.Request(action: action, bundleId: "com.example.app")
            let parsed = IntentNotifications.parse(
                Notification(
                    name: IntentNotifications.name,
                    userInfo: IntentNotifications.userInfo(for: request)
                )
            )
            #expect(parsed == request, "round-trip failed for \(action)")
        }
    }
}
