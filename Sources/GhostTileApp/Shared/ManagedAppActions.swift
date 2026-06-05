@MainActor
protocol ManagedAppActions: AnyObject {
    func open(_ app: ManagedAppItem)
    func show(_ app: ManagedAppItem)
    func hide(_ app: ManagedAppItem)
    func reveal(_ app: ManagedAppItem)
    func remove(_ app: ManagedAppItem)
    func readd(_ app: ManagedAppItem)
    func activate(_ app: ManagedAppItem)
}

extension ManagedAppActions {
    func perform(_ action: ManagedAppItem.PrimaryAction, on app: ManagedAppItem) {
        switch action {
        case .reAdd: readd(app)
        case .showInDock: show(app)
        case .hideFromDock: hide(app)
        case .launch: activate(app)
        }
    }
}
