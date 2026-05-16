import AppIntents
import GhostTileCore

struct HideFromDockIntent: AppIntent {
    static var title: LocalizedStringResource = "Hide App from Dock"
    static var description = IntentDescription(
        "Hide a managed app from the Dock and Cmd+Tab without quitting it."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App") var app: ManagedAppEntity

    func perform() async throws -> some IntentResult {
        IntentNotifications.post(action: .hide, bundleId: app.id)
        return .result()
    }
}
