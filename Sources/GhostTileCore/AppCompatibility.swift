import Foundation

public enum AppCompatibility: Sendable, Equatable {
    case compatible
    case warnings([Warning])
    case unsupported(reason: String)

    public struct Warning: Sendable, Equatable {
        public let entitlement: String
        public let impact: String

        public init(entitlement: String, impact: String) {
            self.entitlement = entitlement
            self.impact = impact
        }
    }

    public static func assess(_ app: AppInfo) throws -> AppCompatibility {
        if let blocker = bundleStructureBlocker(for: app) {
            return .unsupported(reason: blocker)
        }

        let entitlements = try AppPreparationManager.extractEntitlements(app.binaryPath)

        if let key = HardFailEntitlement.firstMatch(in: entitlements) {
            return .unsupported(
                reason:
                "\(app.name) declares '\(key)', which only works under its original signature. Modifying it would break that capability."
            )
        }

        var warnings = bundleStructureWarnings(for: app)
        warnings.append(contentsOf: WarnEntitlement.matches(in: entitlements))
        return warnings.isEmpty ? .compatible : .warnings(warnings)
    }

    /// Keys that trigger AMFI launch kill under ad-hoc resign — must be stripped before codesign.
    public static func entitlementsToStrip() -> Set<String> {
        Set(WarnEntitlement.tccKeys.map(\.key))
    }

    private static func bundleStructureBlocker(for app: AppInfo) -> String? {
        let sysExtDir = (app.appPath as NSString)
            .appendingPathComponent("Contents/Library/SystemExtensions")
        if FileManager.default.fileExists(atPath: sysExtDir) {
            return
                "\(app.name) bundles a system extension. Modifying it would prevent the system extension from loading and break the hardware or service it provides."
        }
        return nil
    }

    private static func bundleStructureWarnings(for app: AppInfo) -> [Warning] {
        var warnings: [Warning] = []
        let receiptPath = (app.appPath as NSString)
            .appendingPathComponent("Contents/_MASReceipt/receipt")
        if FileManager.default.fileExists(atPath: receiptPath) {
            warnings.append(Warning(
                entitlement: "Mac App Store receipt",
                impact:
                "Mac App Store apps might quit on launch or trigger a re-download after modification"
            ))
        }
        return warnings
    }

    private enum HardFailEntitlement {
        static let exact: Set<String> = [
            "com.apple.developer.system-extension.install",
            "com.apple.developer.endpoint-security.client",
            "com.apple.developer.networking.networkextension",
        ]

        static let prefixes: [String] = [
            "com.apple.developer.driverkit",
            "com.apple.developer.usb.",
        ]

        static func firstMatch(in entitlements: [String: Any]) -> String? {
            for key in entitlements.keys {
                if exact.contains(key) { return key }
                if prefixes.contains(where: { key.hasPrefix($0) }) { return key }
            }
            return nil
        }
    }

    private enum WarnEntitlement {
        /// TCC keys — stripped during prepare (AMFI launch kill if kept) and warned about.
        static let tccKeys: [(key: String, impact: String)] = [
            ("com.apple.security.device.audio-input", "Microphone access"),
            ("com.apple.security.device.camera", "Camera access"),
            ("com.apple.security.device.bluetooth", "Bluetooth access"),
            ("com.apple.security.personal-information.addressbook", "Contacts access"),
            ("com.apple.security.personal-information.calendars", "Calendar access"),
            ("com.apple.security.personal-information.location", "Location access"),
            ("com.apple.security.personal-information.photos-library", "Photos library access"),
            ("com.apple.security.automation.apple-events", "AppleScript / cross-app automation"),
        ]

        /// Team-id-bound keys — preserved in the binary but warned about, since they silently fail without a team id.
        static let teamIdBoundKeys: [(key: String, impact: String)] = [
            ("com.apple.security.app-sandbox", "App Sandbox"),
            ("com.apple.security.application-groups", "Shared app group containers"),
            ("keychain-access-groups", "Shared keychain access"),
        ]

        static func matches(in entitlements: [String: Any]) -> [Warning] {
            (tccKeys + teamIdBoundKeys).compactMap { entry in
                entitlements[entry.key] != nil
                    ? Warning(entitlement: entry.key, impact: entry.impact)
                    : nil
            }
        }
    }
}
