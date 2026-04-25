import Foundation

public struct ManagedAppStateSnapshot: Sendable {
    public let records: [ManagedAppRecord]
    public let managedBundleIds: Set<String>

    public init(records: [ManagedAppRecord], managedBundleIds: Set<String>) {
        self.records = records
        self.managedBundleIds = managedBundleIds
    }
}
