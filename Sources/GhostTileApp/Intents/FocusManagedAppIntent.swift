import AppIntents
import GhostTileCore

struct FocusManagedAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Focus App"
    static var description = IntentDescription(
        "Bring a managed app to the front. Launches it visibly if it isn't running."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App") var app: ManagedAppEntity

    func perform() async throws -> some IntentResult {
        IntentNotifications.post(action: .focus, bundleId: app.id)
        return .result()
    }
}
