import AppIntents
import GhostTileCore

struct ManagedAppEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Managed App"
    static var defaultQuery = ManagedAppEntityQuery()

    let id: String
    let name: String
    let appPath: String
    let managed: Bool
    let running: Bool
    let hiddenFromDock: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: stateLabel)
    }

    private var stateLabel: LocalizedStringResource {
        if !running {
            return "Not running"
        }
        return hiddenFromDock ? "Hidden from Dock" : "Visible in Dock"
    }

    init(record: ManagedAppRecord) {
        self.id = record.bundleId
        self.name = record.name
        self.appPath = record.appPath
        self.managed = record.managed
        self.running = record.running
        self.hiddenFromDock = record.hiddenFromDock
    }
}
