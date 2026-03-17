import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Manage: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add an app to the managed list and hide it from Dock.")
        @Flag(name: .long, help: "Force re-preparation before relaunching the app.") var forcePrepare = false
        @Argument(help: "Bundle ID, app name, or app bundle path.") var app: String

        func run() throws {
            let resolved = try AppManager.resolve(app)
            let config = Config.load()

            if config.hidden[resolved.bundleId] != nil {
                let running = NSRunningApplication.runningApplications(
                    withBundleIdentifier: resolved.bundleId)
                if running.first?.activationPolicy == .accessory && !forcePrepare {
                    print("\(resolved.name) is already managed and hidden.")
                    return
                }
            }

            if AppManager.isSIPProtected(resolved.appPath) {
                throw GhostTileError(
                    "\(resolved.name) is in a SIP-protected location.")
            }

            let shouldPrepare = forcePrepare ? true : try AppManager.needsPreparation(resolved)
            if shouldPrepare {
                print("Preparing \(resolved.name)...")
                try AppManager.prepare(resolved)
            }

            print("Restarting \(resolved.name)...")
            try AppManager.quit(resolved.bundleId)
            try AppManager.launchHidden(resolved)

            try Config.addHidden(
                resolved.bundleId,
                app: HiddenApp(
                    name: resolved.name,
                    appPath: resolved.appPath,
                    binaryPath: resolved.binaryPath,
                    prepared: true))

            Thread.sleep(forTimeInterval: 2)
            let launched = NSRunningApplication.runningApplications(
                withBundleIdentifier: resolved.bundleId)
            if launched.first?.activationPolicy == .accessory {
                print("\(resolved.name) is now managed and hidden from Dock.")
            } else if launched.isEmpty {
                print(
                    "Warning: \(resolved.name) may not have launched. Check 'ghosttile status'.")
            } else {
                print(
                    "Warning: \(resolved.name) launched but may override its activation policy.")
            }
        }
    }

    struct Prepare: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Prepare an app for GhostTile without relaunching it.")
        @Flag(name: .long, help: "Force re-preparation even if the app already appears prepared.") var force = false
        @Argument(help: "Bundle ID, app name, or app bundle path.") var app: String

        func run() throws {
            let resolved = try AppManager.resolve(app)

            if AppManager.isSIPProtected(resolved.appPath) {
                throw GhostTileError("\(resolved.name) is in a SIP-protected location.")
            }

            let shouldPrepare = force ? true : try AppManager.needsPreparation(resolved)
            guard shouldPrepare else {
                print("\(resolved.name) is already prepared.")
                return
            }

            print("Preparing \(resolved.name)...")
            try AppManager.prepare(resolved)
            print("\(resolved.name) prepared. No relaunch performed.")
        }
    }
}
