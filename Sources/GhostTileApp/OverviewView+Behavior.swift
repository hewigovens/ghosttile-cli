import SwiftUI

extension OverviewView {
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

    func syncSelection() {
        guard !filteredApps.isEmpty else {
            selectedBundleId = nil
            return
        }

        if let selectedBundleId,
           filteredApps.contains(where: { $0.id == selectedBundleId }) {
            return
        }

        self.selectedBundleId = filteredApps.first?.id
    }

    func openSelectedApp() {
        guard let selectedBundleId,
              let app = filteredApps.first(where: { $0.id == selectedBundleId })
        else { return }

        vm.handleAttentionNotificationClick(bundleId: app.id)
        onDismiss()
    }
}
