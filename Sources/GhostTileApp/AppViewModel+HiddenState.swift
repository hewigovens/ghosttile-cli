import AppKit
import GhostTileCore

extension AppViewModel {
    func autoHideIfNeeded(_ bundleId: String) {
        let autoHide = UserDefaults.standard.object(forKey: "autoHideOnLaunch") as? Bool ?? true
        dockVisibilityController.autoHideIfNeeded(bundleId, autoHideEnabled: autoHide)
    }

    func reapplyHidden() {
        dockVisibilityController.reapplyHiddenState()
        scheduleRefresh(after: 0.5)
    }

    func completeOperation(for bundleId: String, refreshDelay: TimeInterval? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.loading.remove(bundleId)
        }
        scheduleRefresh(after: refreshDelay ?? Self.postOperationRefreshDelay)
    }

    func sendDockVisibilityNotification(
        bundleId: String,
        hidden: Bool,
        refreshDelay: TimeInterval = 0.5
    ) {
        dockVisibilityController.send(bundleId: bundleId, hidden: hidden)
        scheduleRefresh(after: refreshDelay)
    }

    func scheduleRefresh(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.refresh()
        }
    }

    func recordSponsorUse() {
        Task { @MainActor in
            SponsorNudgeController.shared.recordMeaningfulUse()
        }
    }
}
