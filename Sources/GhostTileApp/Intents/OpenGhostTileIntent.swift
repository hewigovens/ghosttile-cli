import AppIntents
import GhostTileCore

struct OpenGhostTileIntent: AppIntent {
    static var title: LocalizedStringResource = "Open GhostTile"
    static var description = IntentDescription(
        "Bring the GhostTile window to the foreground."
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        IntentNotifications.post(action: .openWindow)
        return .result()
    }
}
