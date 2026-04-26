import Foundation

struct ManagedAppsSnapshot {
    let apps: [ManagedAppItem]
    let managedBundleIds: Set<String>
}
