import AppKit
import GhostTileCore

@MainActor
final class DockVisibilityController {
    func autoHideIfNeeded(_ bundleId: String, autoHideEnabled: Bool) {
        guard autoHideEnabled else { return }

        let config = Config.load()
        guard let hiddenApp = config.hidden[bundleId] else { return }

        Log.info("Sending auto-hide notification for launched managed app: \(hiddenApp.name) (\(bundleId))")

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            guard let process = running.first, process.activationPolicy == .regular else { return }

            Task { @MainActor in
                self.send(bundleId: bundleId, hidden: true)
            }
        }
    }

    func reapplyHiddenState() {
        let config = Config.load()
        guard !config.hidden.isEmpty else { return }

        Log.info("Reapplying hidden state for \(config.hidden.count) app(s)")

        for (bundleId, hiddenApp) in config.hidden {
            reapplyHiddenState(bundleId: bundleId, hiddenApp: hiddenApp)
        }
    }

    func reapplyHiddenState(bundleId: String, hiddenApp: HiddenApp) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        guard let process = running.first else { return }

        if process.activationPolicy == .accessory {
            Log.info("\(hiddenApp.name) is already hidden on startup")
            return
        }

        Log.info("Sending hide notification to \(hiddenApp.name) on startup")
        send(bundleId: bundleId, hidden: true)
    }

    func send(bundleId: String, hidden: Bool) {
        ManagedAppNotifications.post(bundleId: bundleId, action: hidden ? .hide : .show)
    }
}
