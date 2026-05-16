import AppIntents

struct GhostTileShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HideFromDockIntent(),
            phrases: [
                "Hide \(\.$app) with \(.applicationName)",
                "Hide \(\.$app) from the Dock with \(.applicationName)",
                "\(.applicationName) hide \(\.$app)",
            ],
            shortTitle: "Hide from Dock",
            systemImageName: "eye.slash"
        )
        AppShortcut(
            intent: ShowInDockIntent(),
            phrases: [
                "Show \(\.$app) with \(.applicationName)",
                "Show \(\.$app) in the Dock with \(.applicationName)",
                "\(.applicationName) show \(\.$app)",
            ],
            shortTitle: "Show in Dock",
            systemImageName: "eye"
        )
        AppShortcut(
            intent: FocusManagedAppIntent(),
            phrases: [
                "Focus \(\.$app) with \(.applicationName)",
                "Activate \(\.$app) with \(.applicationName)",
                "\(.applicationName) focus \(\.$app)",
            ],
            shortTitle: "Focus App",
            systemImageName: "macwindow.on.rectangle"
        )
        AppShortcut(
            intent: OpenGhostTileIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show \(.applicationName)",
            ],
            shortTitle: "Open GhostTile",
            systemImageName: "rectangle.stack"
        )
    }
}
