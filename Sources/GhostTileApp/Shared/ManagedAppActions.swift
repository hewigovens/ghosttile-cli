@MainActor
protocol ManagedAppActions: AnyObject {
    func open(_ app: ManagedAppItem)
    func show(_ app: ManagedAppItem)
    func hide(_ app: ManagedAppItem)
    func reveal(_ app: ManagedAppItem)
    func remove(_ app: ManagedAppItem)
}
