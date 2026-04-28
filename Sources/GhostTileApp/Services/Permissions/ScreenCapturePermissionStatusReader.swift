import CoreGraphics
import ScreenCaptureKit

enum ScreenCapturePermissionStatusReader {
    static func isAllowed() async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        return await canEnumerateShareableContent()
    }

    private static func canEnumerateShareableContent() async -> Bool {
        await withCheckedContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, _ in
                continuation.resume(returning: content != nil)
            }
        }
    }
}
