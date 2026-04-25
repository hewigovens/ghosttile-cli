import AppKit
import Foundation

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
        window.contentView = PermissionGuidanceOverlayView(pane: pane, target: target, onClose: onClose)
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

private final class PermissionGuidanceOverlayView: NSView {
    private let onClose: () -> Void

    init(pane: SystemSettingsPane, target: PermissionGuidanceTarget, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: 420, height: 124)))
        translatesAutoresizingMaskIntoConstraints = false
        setup(pane: pane, target: target)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(pane: SystemSettingsPane, target: PermissionGuidanceTarget) {
        let materialView = NSVisualEffectView()
        materialView.translatesAutoresizingMaskIntoConstraints = false
        materialView.material = .popover
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 18
        materialView.layer?.masksToBounds = true
        materialView.layer?.borderWidth = 0.5
        materialView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.18).cgColor
        addSubview(materialView)

        let tintView = NSView()
        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.78).cgColor
        materialView.addSubview(tintView)

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        materialView.addSubview(closeButton)

        let directionBadge = NSView()
        directionBadge.translatesAutoresizingMaskIntoConstraints = false
        directionBadge.wantsLayer = true
        directionBadge.layer?.cornerRadius = 10
        directionBadge.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        materialView.addSubview(directionBadge)

        let arrowView = NSImageView()
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)
        arrowView.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        arrowView.contentTintColor = NSColor.controlAccentColor
        directionBadge.addSubview(arrowView)

        let titleLabel = NSTextField(labelWithString: "Drag \(target.fileName) into the list above")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = NSColor.labelColor.withAlphaComponent(0.92)
        materialView.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "Then turn on \(pane.title).")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        materialView.addSubview(subtitleLabel)

        let dragSource = PermissionDragSourceView(target: target)
        materialView.addSubview(dragSource)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 420),
            heightAnchor.constraint(equalToConstant: 124),

            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintView.leadingAnchor.constraint(equalTo: materialView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: materialView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: materialView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: materialView.bottomAnchor),

            closeButton.trailingAnchor.constraint(equalTo: materialView.trailingAnchor, constant: -12),
            closeButton.topAnchor.constraint(equalTo: materialView.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),

            directionBadge.leadingAnchor.constraint(equalTo: materialView.leadingAnchor, constant: 22),
            directionBadge.topAnchor.constraint(equalTo: materialView.topAnchor, constant: 16),
            directionBadge.widthAnchor.constraint(equalToConstant: 32),
            directionBadge.heightAnchor.constraint(equalToConstant: 32),

            arrowView.centerXAnchor.constraint(equalTo: directionBadge.centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: directionBadge.centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 16),
            arrowView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: directionBadge.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: materialView.topAnchor, constant: 15),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            dragSource.leadingAnchor.constraint(equalTo: materialView.leadingAnchor, constant: 16),
            dragSource.trailingAnchor.constraint(equalTo: materialView.trailingAnchor, constant: -16),
            dragSource.topAnchor.constraint(equalTo: materialView.topAnchor, constant: 62),
            dragSource.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    @objc
    private func closePressed() {
        onClose()
    }
}
