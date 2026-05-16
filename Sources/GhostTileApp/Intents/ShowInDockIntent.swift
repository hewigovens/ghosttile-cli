import AppIntents
import GhostTileCore

struct ShowInDockIntent: AppIntent {
    static var title: LocalizedStringResource = "Show App in Dock"
    static var description = IntentDescription(
        "Bring a hidden managed app back to the Dock. Launches the app if it isn't running."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App") var app: ManagedAppEntity

    func perform() async throws -> some IntentResult {
        IntentNotifications.post(action: .show, bundleId: app.id)
        return .result()
    }
}
