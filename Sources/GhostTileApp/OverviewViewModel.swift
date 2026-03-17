import Combine
import Foundation
import SwiftUI

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var query = "" {
        didSet { syncSelection() }
    }
    @Published var selectedBundleId: String?

    private let store: ManagedAppsStore
    private var subscriptions: Set<AnyCancellable> = []

    init(store: ManagedAppsStore) {
        self.store = store

        store.$apps
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.syncSelection()
            }
            .store(in: &subscriptions)
    }

    var hiddenApps: [ManagedAppItem] {
        store.apps.filter(\.isHidden)
    }

    var filteredApps: [ManagedAppItem] {
        hiddenApps.filtered(by: query)
    }

    func ensureInitialSelection() {
        if selectedBundleId == nil {
            selectedBundleId = filteredApps.first?.id
        }
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        guard !filteredApps.isEmpty else { return }

        let currentIndex = filteredApps.firstIndex { $0.id == selectedBundleId } ?? 0
        let nextIndex: Int

        switch direction {
        case .left, .up:
            nextIndex = max(0, currentIndex - 1)
        case .right, .down:
            nextIndex = min(filteredApps.count - 1, currentIndex + 1)
        @unknown default:
            nextIndex = currentIndex
        }

        selectedBundleId = filteredApps[nextIndex].id
    }

    func selectedApp() -> ManagedAppItem? {
        guard let selectedBundleId else { return nil }
        return filteredApps.first(where: { $0.id == selectedBundleId })
    }

    func syncSelection() {
        guard !filteredApps.isEmpty else {
            selectedBundleId = nil
            return
        }

        if let selectedBundleId,
            filteredApps.contains(where: { $0.id == selectedBundleId })
        {
            return
        }

        self.selectedBundleId = filteredApps.first?.id
    }
}
