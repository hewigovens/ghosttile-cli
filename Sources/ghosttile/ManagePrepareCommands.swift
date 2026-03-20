import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Manage: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add an app to the managed list and hide it from Dock."
        )
        @Flag(name: .long, help: "Force re-preparation before relaunching the app.") var forcePrepare = false
        @Argument(help: "Bundle ID, app name, or app bundle path.") var app: String

        func run() throws {
            let resolved = try AppManager.resolve(app)

            if Config.load().hidden[resolved.bundleId] != nil {
                if AppManager.runningApps(resolved.bundleId).first?.activationPolicy == .accessory, !forcePrepare {
                    print("\(resolved.name) is already managed and hidden.")
                    return
                }
            }

            try validateNotSIPProtected(resolved)
            try prepareIfNeeded(resolved, force: forcePrepare)

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
        @Argument(help: "Bundle ID, app name, or app bundle path.") var app: String

        func run() throws {
            let resolved = try AppManager.resolve(app)
            try validateNotSIPProtected(resolved)

            let needs = try force || AppManager.needsPreparation(resolved)
            guard needs else {
                print("\(resolved.name) is already prepared.")
                return
            }

            try prepareIfNeeded(resolved, force: force)
            print("\(resolved.name) prepared. No relaunch performed.")
        }
    }
}
