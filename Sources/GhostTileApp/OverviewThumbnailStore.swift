import AppKit
import CoreGraphics
import GhostTileCore
import ScreenCaptureKit

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

private struct CaptureTarget {
    let bundleId: String
    let pid: pid_t
}

private func captureThumbnail(for target: CaptureTarget) async -> CGImage? {
    guard #available(macOS 14.0, *) else {
        return nil
    }

    do {
        guard let window = try await representativeWindow(pid: target.pid) else {
            Log.debug("Overview capture unavailable for \(target.bundleId)")
            return nil
        }

        return try await captureImage(for: window)
    } catch {
        Log.debug("Overview capture failed for \(target.bundleId): \(error)")
        return nil
    }
}

@available(macOS 14.0, *)
private func representativeWindow(pid: pid_t) async throws -> SCWindow? {
    let shareableContent = try await currentShareableContent()
    return shareableContent.windows
        .filter { window in
            guard let owningApplication = window.owningApplication else { return false }
            return owningApplication.processID == pid
                && window.windowLayer == 0
                && window.frame.width > 80
                && window.frame.height > 80
        }
        .max { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }
}

@available(macOS 14.0, *)
private func currentShareableContent() async throws -> SCShareableContent {
    try await withCheckedThrowingContinuation { continuation in
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) {
            shareableContent, error in
            if let shareableContent {
                continuation.resume(returning: shareableContent)
            } else {
                continuation.resume(
                    throwing: error ?? GhostTileError("Unable to enumerate shareable windows.")
                )
            }
        }
    }
}

@available(macOS 14.0, *)
private func captureImage(for window: SCWindow) async throws -> CGImage {
    let filter = SCContentFilter(desktopIndependentWindow: window)
    let configuration = SCStreamConfiguration()
    configuration.width = size_t(max(1, Int(window.frame.width * 2)))
    configuration.height = size_t(max(1, Int(window.frame.height * 2)))
    configuration.scalesToFit = true
    configuration.preservesAspectRatio = true
    configuration.showsCursor = false
    configuration.ignoreShadowsSingleWindow = true

    return try await withCheckedThrowingContinuation { continuation in
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) {
            image, error in
            if let image {
                continuation.resume(returning: image)
            } else {
                continuation.resume(
                    throwing: error ?? GhostTileError("Unable to capture window preview.")
                )
            }
        }
    }
}

private func resize(image: NSImage, fitting size: NSSize) -> NSImage {
    guard image.size.width > 0, image.size.height > 0 else {
        return image
    }

    let widthScale = size.width / image.size.width
    let heightScale = size.height / image.size.height
    let scale = min(widthScale, heightScale)
    let finalSize = NSSize(
        width: max(1, floor(image.size.width * scale)),
        height: max(1, floor(image.size.height * scale))
    )
    let output = NSImage(size: finalSize)
    output.lockFocus()
    image.draw(in: CGRect(origin: .zero, size: finalSize))
    output.unlockFocus()
    return output
}
