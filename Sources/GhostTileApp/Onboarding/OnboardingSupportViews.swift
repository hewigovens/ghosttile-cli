import AppKit
import SwiftUI

struct OnboardingWindowCenterer: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            guard let screen = window.screen ?? NSScreen.main else {
                window.center()
                return
            }

            let visibleFrame = screen.visibleFrame
            var frame = window.frame
            frame.origin.x = visibleFrame.midX - (frame.width / 2)
            frame.origin.y = visibleFrame.midY - (frame.height / 2)
            window.setFrame(frame, display: false)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
