import AppKit
import Foundation

@MainActor
final class PermissionGuidanceController {
    static let shared = PermissionGuidanceController()

    private var overlayController: PermissionOverlayWindowController?
    private var trackingTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var didPresentCurrentOverlay = false

    func present(pane: SystemSettingsPane, target: PermissionGuidanceTarget) {
        dismiss()

        overlayController = PermissionOverlayWindowController(
            pane: pane,
            target: target,
            onClose: { [weak self] in
                self?.dismiss()
            }
        )
        NSWorkspace.shared.open(pane.settingsURL)
        startTracking()
    }

    func open(pane: SystemSettingsPane) {
        NSWorkspace.shared.open(pane.settingsURL)
    }

    func dismiss() {
        trackingTimer?.invalidate()
        trackingTimer = nil

        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }

        overlayController?.close()
        overlayController = nil
        didPresentCurrentOverlay = false
    }

    private func startTracking() {
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshOverlayPosition()
            }
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshOverlayPosition()
            }
        }

        refreshOverlayPosition()
    }

    private func refreshOverlayPosition() {
        guard let snapshot = SystemSettingsWindowTracker.frontmostWindow() else {
            overlayController?.hide()
            return
        }

        if didPresentCurrentOverlay {
            overlayController?.updatePosition(settingsFrame: snapshot.frame, visibleFrame: snapshot.visibleFrame)
        } else {
            overlayController?.present(settingsFrame: snapshot.frame, visibleFrame: snapshot.visibleFrame)
            didPresentCurrentOverlay = true
        }
    }
}
