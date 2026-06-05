import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Manage: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add an app to the managed list and hide it from Dock."
        )
        @Flag(name: .long, help: "Force re-preparation before relaunching the app.") var forcePrepare = false
        @Flag(
            name: .long,
            help: "Proceed despite compatibility warnings about features that may break after preparation."
        ) var acceptWarnings = false
        @Flag(
            name: .long,
            help: "Manage an app-group app anyway by running it unsandboxed (loses sandbox protection)."
        ) var unsandbox = false
        @Argument(help: "Bundle ID, app name, or app bundle path.") var app: String

        func run() throws {
            let resolved = try AppManager.resolve(app)
            let hiddenApp = Config.load().hidden[resolved.bundleId]
            let requiresReAdd = hiddenApp != nil && !GhosthidePatch.isApplied(to: resolved.binaryPath)

            if hiddenApp != nil {
                let alreadyHidden = AppManager.runningApps(resolved.bundleId).first?.activationPolicy == .accessory
                if requiresReAdd {
                    print(
                        "\(resolved.name) was updated since GhostTile prepared it. Re-preparing this version..."
                    )
                } else if alreadyHidden, !forcePrepare {
                    print("\(resolved.name) is already managed and hidden.")
                    return
                }
            }

            let options = PrepareOptions(
                acceptWarnings: acceptWarnings,
                refreshBackup: requiresReAdd,
                unsandbox: unsandbox
            )
            try validateNotSIPProtected(resolved)
            try validateCompatibility(resolved, options: options)
            try prepareIfNeeded(resolved, force: forcePrepare || requiresReAdd, options: options)

            print("Restarting \(resolved.name)...")
            try AppManager.quit(resolved.bundleId)
            try AppManager.launchHidden(resolved)
            try addToConfig(resolved)

            Thread.sleep(forTimeInterval: 2)
            let launched = AppManager.runningApps(resolved.bundleId)
            if launched.first?.activationPolicy == .accessory {
                print("\(resolved.name) is now managed and hidden from Dock.")
            } else if launched.isEmpty {
                print(
                    "Warning: \(resolved.name) may not have launched. Check 'ghosttile status'."
                )
            } else {
                print(
                    "Warning: \(resolved.name) launched but may override its activation policy."
                )
            }
        }
    }

    struct Prepare: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prepare an app for GhostTile without relaunching it."
        )
        @Flag(name: .long, help: "Force re-preparation even if the app already appears prepared.") var force = false
        @Flag(
            name: .long,
            help: "Proceed despite compatibility warnings about features that may break after preparation."
        ) var acceptWarnings = false
        @Flag(
            name: .long,
            help: "Manage an app-group app anyway by running it unsandboxed (loses sandbox protection)."
        ) var unsandbox = false
        @Argument(help: "Bundle ID, app name, or app bundle path.") var app: String

        func run() throws {
            let resolved = try AppManager.resolve(app)
            try validateNotSIPProtected(resolved)

            let needs = try force || AppManager.needsPreparation(resolved)
            guard needs else {
                print("\(resolved.name) is already prepared.")
                return
            }

            // Re-preparing an updated managed app must refresh the stale pre-update backup.
            let hiddenApp = Config.load().hidden[resolved.bundleId]
            let requiresReAdd = hiddenApp != nil && !GhosthidePatch.isApplied(to: resolved.binaryPath)
            let options = PrepareOptions(
                acceptWarnings: acceptWarnings,
                refreshBackup: requiresReAdd,
                unsandbox: unsandbox
            )

            try validateCompatibility(resolved, options: options)
            try prepareIfNeeded(resolved, force: force, options: options)
            print("\(resolved.name) prepared. No relaunch performed.")
        }
    }
}
