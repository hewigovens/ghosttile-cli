import AppIntents
import GhostTileCore

struct ManagedAppEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [ManagedAppEntity.ID]) async throws -> [ManagedAppEntity] {
        let lookup = await snapshotByBundleId()
        return identifiers.compactMap { lookup[$0] }
    }

    func suggestedEntities() async throws -> [ManagedAppEntity] {
        try await allEntities()
    }

    func allEntities() async throws -> [ManagedAppEntity] {
        await snapshotEntities { $0.managed }
    }

    @MainActor
    private func snapshotByBundleId() -> [String: ManagedAppEntity] {
        let records = ManagedAppStateReader.makeSnapshot().records
        var map: [String: ManagedAppEntity] = [:]
        for record in records {
            map[record.bundleId] = ManagedAppEntity(record: record)
        }
        return map
    }

    @MainActor
    private func snapshotEntities(matching predicate: (ManagedAppRecord) -> Bool) -> [ManagedAppEntity] {
        ManagedAppStateReader.makeSnapshot().records
            .filter(predicate)
            .map(ManagedAppEntity.init)
    }
}
