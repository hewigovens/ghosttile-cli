import Combine
import Foundation

@MainActor
final class MainWindowViewModel: ObservableObject {
    @Published var query = ""
    @Published var dropTargeted = false

    private let store: ManagedAppsStore
    private var subscriptions: Set<AnyCancellable> = []

    init(store: ManagedAppsStore) {
        self.store = store

        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscriptions)
    }

    var managedApps: [ManagedAppItem] {
        store.apps.filter(\.isHidden).filtered(by: query)
    }

    var runningApps: [ManagedAppItem] {
        store.apps.filter {
            !$0.isHidden && !$0.isSIPProtected && !$0.id.hasPrefix("com.apple.")
        }.filtered(by: query)
    }

    var totalManagedCount: Int {
        store.apps.filter(\.isHidden).count
    }

    var runningCount: Int {
        store.apps.filter { !$0.isHidden && !$0.isSIPProtected && !$0.id.hasPrefix("com.apple.") }.count
    }

    var hiddenRunningCount: Int {
        store.apps.filter { $0.isHidden && $0.isRunning }.count
    }
}
