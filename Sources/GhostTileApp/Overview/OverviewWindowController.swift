import AppKit
import SwiftUI

final class OverviewWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: AppViewModel
    private let thumbnailStore = OverviewThumbnailStore()

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel

        let panel = OverviewPanel()
        panel.isReleasedWhenClosed = false
        panel.delegate = nil

        super.init(window: panel)

        panel.delegate = self
        panel.contentViewController = NSHostingController(
            rootView: OverviewView(
                appViewModel: viewModel,
                thumbnailStore: thumbnailStore,
                onDismiss: { [weak panel] in panel?.orderOut(nil) }
            )
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            showOverview()
        }
    }

    func showOverview() {
        viewModel.refresh()

        guard let panel = window else { return }
        panel.setFrame(frameForCurrentScreen(), display: false)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.thumbnailStore.warmCache(for: self?.viewModel.hiddenApps ?? [], force: true)
        }
    }

    private func frameForCurrentScreen() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)

        let targetWidth = min(max(980, visible.width * 0.74), 1200)
        let targetHeight = min(max(620, visible.height * 0.76), 820)

        return CGRect(
            x: visible.midX - (targetWidth / 2),
            y: visible.midY - (targetHeight / 2),
            width: targetWidth,
            height: targetHeight
        )
    }

    func windowDidResignKey(_: Notification) {
        window?.orderOut(nil)
    }
}

private final class OverviewPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        hidesOnDeactivate = true
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }
}
