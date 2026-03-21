import AppKit
import CoreGraphics
import GhostTileCore
import ScreenCaptureKit

struct CaptureTarget {
    let bundleId: String
    let pid: pid_t
}

func captureThumbnail(for target: CaptureTarget) async -> CGImage? {
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
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { shareableContent, error in
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
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
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

func resize(image: NSImage, fitting size: NSSize) -> NSImage {
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
