import AppKit
import Foundation
import SwiftUI

final class PermissionOverlayWindowController: NSWindowController {
    private let windowSize = NSSize(width: 420, height: 124)
    private let arrowCenterX: CGFloat = 38

    init(
        pane: SystemSettingsPane,
        target: PermissionGuidanceTarget,
        onClose: @escaping () -> Void
    ) {
        let window = PassivePermissionPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        configure(window)
        window.contentView = NSHostingView(
            rootView: PermissionGuidanceOverlayView(
                pane: pane,
                target: target,
                onClose: onClose
            )
            .frame(width: windowSize.width, height: windowSize.height)
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func close() {
        window?.orderOut(nil)
        super.close()
    }

    func present(settingsFrame: CGRect, visibleFrame: CGRect) {
        guard let window else { return }
        window.setFrame(
            NSRect(origin: origin(for: settingsFrame, visibleFrame: visibleFrame), size: windowSize),
            display: false
        )
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().alphaValue = 1
        }
    }

    func updatePosition(settingsFrame: CGRect, visibleFrame: CGRect) {
        guard let window else { return }
        window.setFrameOrigin(origin(for: settingsFrame, visibleFrame: visibleFrame))
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func configure(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.animationBehavior = .none
    }

    private func origin(for settingsFrame: CGRect, visibleFrame: CGRect) -> NSPoint {
        let sidebarWidth: CGFloat = 170
        let contentMinX = settingsFrame.minX + sidebarWidth
        let addButtonCenterX = contentMinX + 34
        let preferredX = addButtonCenterX - arrowCenterX
        let preferredY = settingsFrame.minY + 14
        let minX = visibleFrame.minX + 8
        let maxX = visibleFrame.maxX - windowSize.width - 8
        let minY = visibleFrame.minY + 8
        let maxY = visibleFrame.maxY - windowSize.height - 8

        return NSPoint(
            x: min(max(preferredX, minX), maxX),
            y: min(max(preferredY, minY), maxY)
        )
    }
}

private final class PassivePermissionPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
