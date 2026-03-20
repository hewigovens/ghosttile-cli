import AppKit
import SwiftUI

extension OnboardingView {
    func startIconLoop() {
        iconLoopTask?.cancel()
        iconLoopTask = Task {
            try? await Task.sleep(for: .seconds(0.9))

            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        iconFlipped.toggle()
                    }
                }

                try? await Task.sleep(for: .seconds(1.4))
            }
        }
    }

    func openAppManagementSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
            NSWorkspace.shared.open(url)
        }
    }

    func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
