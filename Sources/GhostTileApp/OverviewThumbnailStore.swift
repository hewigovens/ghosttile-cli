import AppKit
import Foundation

@MainActor
final class OverviewThumbnailStore: ObservableObject {
    private static let screenCaptureSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )

    enum CapturePermissionState {
        case unknown
        case available
        case needsAccess
    }

    @Published private(set) var thumbnails: [String: NSImage] = [:]
    @Published private(set) var capturePermissionState: CapturePermissionState = .unknown

    private var lastCaptureAt: [String: Date] = [:]
    private var inFlight: Set<String> = []
    private let captureCooldown: TimeInterval = 15
    private let targetSize = NSSize(width: 520, height: 320)

    var supportsLivePreviews: Bool {
        if #available(macOS 14.0, *) {
            return true
        }

        return false
    }

    func thumbnail(for bundleId: String) -> NSImage? {
        thumbnails[bundleId]
    }

    func warmCache(for apps: [AppViewModel.AppItem], force: Bool = false) {
        refreshCapturePermissionState()
        guard supportsLivePreviews else {
            thumbnails.removeAll()
            return
        }

        let runningApps = apps.compactMap { app -> (AppViewModel.AppItem, pid_t)? in
            guard app.isRunning,
                  let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first
            else { return nil }

            return (app, running.processIdentifier)
        }

        let runningIDs = Set(runningApps.map { $0.0.id })
        thumbnails = thumbnails.filter { runningIDs.contains($0.key) }
        lastCaptureAt = lastCaptureAt.filter { runningIDs.contains($0.key) }

        guard capturePermissionState != .needsAccess else { return }

        for (app, pid) in runningApps {
            guard shouldCapture(bundleId: app.id, force: force) else { continue }
            inFlight.insert(app.id)

            Task(priority: .userInitiated) { [targetSize = self.targetSize] in
                let image = await captureThumbnail(for: CaptureTarget(bundleId: app.id, pid: pid))
                self.inFlight.remove(app.id)
                self.lastCaptureAt[app.id] = Date()

                guard let image else { return }

                let preview = NSImage(
                    cgImage: image,
                    size: NSSize(width: image.width, height: image.height)
                )
                self.thumbnails[app.id] = resize(image: preview, fitting: targetSize)
            }
        }
    }

    func requestCaptureAccess() {
        if CGPreflightScreenCaptureAccess() {
            capturePermissionState = .available
            return
        }

        _ = CGRequestScreenCaptureAccess()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.refreshCapturePermissionState()
            guard self.capturePermissionState == .needsAccess else { return }

            if let url = Self.screenCaptureSettingsURL {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func refreshCapturePermissionState() {
        capturePermissionState = CGPreflightScreenCaptureAccess() ? .available : .needsAccess
    }

    private func shouldCapture(bundleId: String, force: Bool) -> Bool {
        if inFlight.contains(bundleId) {
            return false
        }

        if force || thumbnails[bundleId] == nil {
            return true
        }

        guard let lastCaptureAt = lastCaptureAt[bundleId] else {
            return true
        }

        return Date().timeIntervalSince(lastCaptureAt) >= captureCooldown
    }
}
