import AppKit
import CoreGraphics
import Foundation

enum SystemSettingsWindowTracker {
    private static let bundleIdentifier = "com.apple.systempreferences"

    static func frontmostWindow() -> SystemSettingsWindowSnapshot? {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier else {
            return nil
        }

        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .max(by: { ($0.activationPolicy == .prohibited ? 0 : 1) < ($1.activationPolicy == .prohibited ? 0 : 1) })
        else {
            return nil
        }

        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], .zero)
            as? [[String: Any]]
        else {
            return nil
        }

        let windows = windowInfo.compactMap { info -> SystemSettingsWindowSnapshot? in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier
            else {
                return nil
            }

            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                return nil
            }

            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else {
                return nil
            }

            let cgFrame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            let converted = appKitGeometry(from: cgFrame)
            guard converted.frame.width > 320, converted.frame.height > 240 else {
                return nil
            }

            return SystemSettingsWindowSnapshot(frame: converted.frame, visibleFrame: converted.visibleFrame)
        }

        return windows.max {
            ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
        }
    }

    private static func appKitGeometry(from cgFrame: CGRect) -> (frame: CGRect, visibleFrame: CGRect) {
        let screens = NSScreen.screens.compactMap { screen -> SystemSettingsDisplayGeometry? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }

            let displayID = CGDirectDisplayID(number.uint32Value)
            return SystemSettingsDisplayGeometry(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                cgBounds: CGDisplayBounds(displayID)
            )
        }

        guard let matchedScreen = screens
            .filter({ $0.cgBounds.intersects(cgFrame) })
            .max(by: { lhs, rhs in
                let lhsArea = lhs.cgBounds.intersection(cgFrame).width * lhs.cgBounds.intersection(cgFrame).height
                let rhsArea = rhs.cgBounds.intersection(cgFrame).width * rhs.cgBounds.intersection(cgFrame).height
                return lhsArea < rhsArea
            })
        else {
            let visibleFrame = NSScreen.main?.visibleFrame ?? CGRect(origin: .zero, size: cgFrame.size)
            return (frame: cgFrame, visibleFrame: visibleFrame)
        }

        let localX = cgFrame.minX - matchedScreen.cgBounds.minX
        let localY = cgFrame.minY - matchedScreen.cgBounds.minY
        let frame = CGRect(
            x: matchedScreen.frame.minX + localX,
            y: matchedScreen.frame.maxY - localY - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )

        return (frame: frame, visibleFrame: matchedScreen.visibleFrame)
    }
}
