import Foundation
@testable import GhostTileCore
import Testing

@Suite("AppCompatibility")
final class AppCompatibilityTests {
    private let tempDir: TestTempDirectory

    init() throws {
        tempDir = try TestTempDirectory(prefix: "ghosttile-compat")
    }

    @Test func cleanAppIsCompatible() throws {
        let app = try buildApp()
        #expect(try AppCompatibility.assess(app) == .compatible)
    }

    @Test func systemExtensionFolderTriggersHardFail() throws {
        let app = try buildApp { bundlePath in
            try FileManager.default.createDirectory(
                atPath: bundlePath + "/Contents/Library/SystemExtensions",
                withIntermediateDirectories: true
            )
        }
        try expectUnsupported(AppCompatibility.assess(app), contains: "system extension")
    }

    @Test func tccEntitlementProducesWarning() throws {
        let app = try buildApp(entitlements: ["com.apple.security.device.audio-input": true])
        try expectWarning(AppCompatibility.assess(app), entitlement: "com.apple.security.device.audio-input")
    }

    @Test func systemExtensionEntitlementTriggersHardFail() throws {
        let app = try buildApp(entitlements: ["com.apple.developer.system-extension.install": true])
        try expectUnsupported(AppCompatibility.assess(app), contains: "system-extension.install")
    }

    @Test func macAppStoreReceiptProducesWarning() throws {
        let app = try buildApp { bundlePath in
            let receiptDir = bundlePath + "/Contents/_MASReceipt"
            try FileManager.default.createDirectory(atPath: receiptDir, withIntermediateDirectories: true)
            try Data().write(to: URL(fileURLWithPath: receiptDir + "/receipt"))
        }
        try expectWarning(AppCompatibility.assess(app), entitlement: "Mac App Store receipt")
    }

    @Test func entitlementsToStripCoversTccButNotTeamIdBound() {
        let strip = AppCompatibility.entitlementsToStrip()
        #expect(strip.contains("com.apple.security.device.camera"))
        #expect(strip.contains("com.apple.security.automation.apple-events"))
        #expect(!strip.contains("com.apple.security.app-sandbox"))
        #expect(!strip.contains("com.apple.security.application-groups"))
        #expect(!strip.contains("keychain-access-groups"))
    }

    @Test func teamIdBoundEntitlementProducesWarning() throws {
        let app = try buildApp(entitlements: ["com.apple.security.application-groups": ["TEAMID.example.group"]])
        try expectWarning(
            AppCompatibility.assess(app),
            entitlement: "com.apple.security.application-groups"
        )
    }

    // MARK: - Helpers

    private func buildApp(
        entitlements: [String: Any]? = nil,
        configure: ((String) throws -> Void)? = nil
    ) throws -> AppInfo {
        let built = try TestAppHelper.buildTestApp(in: tempDir.url)
        if let entitlements {
            try resign(binaryPath: built.binaryPath, entitlements: entitlements)
        }
        try configure?(built.bundlePath)
        return AppInfo(
            bundleId: TestAppHelper.bundleID,
            name: "TestApp",
            appPath: built.bundlePath,
            binaryPath: built.binaryPath
        )
    }

    private func resign(binaryPath: String, entitlements: [String: Any]) throws {
        let entitlementsPath = tempDir.url.appendingPathComponent("entitlements.plist").path
        let data = try PropertyListSerialization.data(
            fromPropertyList: entitlements, format: .xml, options: 0
        )
        try data.write(to: URL(fileURLWithPath: entitlementsPath))
        try ShellRunner.run("/usr/bin/codesign", arguments: [
            "--force", "--sign", "-", "--entitlements", entitlementsPath, binaryPath,
        ])
    }

    private func expectUnsupported(
        _ result: AppCompatibility,
        contains substring: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard case let .unsupported(reason) = result else {
            Issue.record("Expected .unsupported, got \(result)", sourceLocation: sourceLocation)
            return
        }
        #expect(
            reason.contains(substring),
            "reason='\(reason)' missing '\(substring)'",
            sourceLocation: sourceLocation
        )
    }

    private func expectWarning(
        _ result: AppCompatibility,
        entitlement: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard case let .warnings(warnings) = result else {
            Issue.record("Expected .warnings, got \(result)", sourceLocation: sourceLocation)
            return
        }
        #expect(
            warnings.contains { $0.entitlement == entitlement },
            "warnings=\(warnings) missing entitlement '\(entitlement)'",
            sourceLocation: sourceLocation
        )
    }
}
