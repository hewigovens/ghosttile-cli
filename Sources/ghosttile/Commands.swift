import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct Manage: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add an app to the managed list and hide it from Dock.")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let dylibPath = try Dylib.ensureDylib()
            let resolved = try AppManager.resolve(app)
            let config = Config.load()

            if config.hidden[resolved.bundleId] != nil {
                let running = NSRunningApplication.runningApplications(
                    withBundleIdentifier: resolved.bundleId)
                if running.first?.activationPolicy == .accessory {
                    print("\(resolved.name) is already managed and hidden.")
                    return
                }
            }

            if AppManager.isSIPProtected(resolved.appPath) {
                throw GhostTileError(
                    "\(resolved.name) is in a SIP-protected location.")
            }

            if try AppManager.needsPreparation(resolved) {
                print("Preparing \(resolved.name)...")
                try AppManager.prepare(resolved)
            }

            print("Restarting \(resolved.name)...")
            try AppManager.quit(resolved.bundleId)
            try AppManager.launchHidden(resolved, dylibPath: dylibPath)

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

    struct Restore: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove an app from the managed list and restore it.")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let config = Config.load()
            let q = app.lowercased()

            let match = config.hidden.first {
                $0.key.lowercased().contains(q)
                    || $0.value.name.lowercased().contains(q)
            }

            guard let (bundleId, hiddenApp) = match else {
                throw GhostTileError(
                    "'\(app)' is not managed. Run 'ghosttile status' to see managed apps.")
            }

            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            if !running.isEmpty {
                print("Quitting \(hiddenApp.name)...")
                try AppManager.quit(bundleId)
            }

            print("Restoring \(hiddenApp.name)...")
            try AppManager.restoreBinary(bundleId, binaryPath: hiddenApp.binaryPath, appPath: hiddenApp.appPath)
            try Config.removeHidden(bundleId)
            try AppManager.launchNormal(hiddenApp.appPath)
            print("\(hiddenApp.name) restored and visible in Dock.")
        }
    }

    struct Hide: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Hide a managed app from Dock (send hide notification).")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let (bundleId, hiddenApp) = try resolveManaged(app)

            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            guard !running.isEmpty else {
                print("\(hiddenApp.name) is not running.")
                return
            }

            let name = "\(bundleId).ghosttile.hide"
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name(name), object: nil, userInfo: nil,
                deliverImmediately: true)
            print("\(hiddenApp.name) hidden from Dock.")
        }
    }

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show a managed app in Dock (send show notification).")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let (bundleId, hiddenApp) = try resolveManaged(app)

            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            guard !running.isEmpty else {
                print("\(hiddenApp.name) is not running.")
                return
            }

            let name = "\(bundleId).ghosttile.show"
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name(name), object: nil, userInfo: nil,
                deliverImmediately: true)
            print("\(hiddenApp.name) shown in Dock.")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List running apps.")

        func run() throws {
            let config = Config.load()
            let apps =
                NSWorkspace.shared.runningApplications
                .filter {
                    $0.bundleIdentifier != nil
                        && ($0.activationPolicy == .regular
                            || config.hidden[$0.bundleIdentifier!] != nil)
                }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

            if apps.isEmpty {
                print("No running apps.")
                return
            }

            let maxName = max(apps.map { ($0.localizedName ?? "").count }.max() ?? 0, 12)

            for app in apps {
                let name =
                    (app.localizedName ?? "Unknown")
                    .padding(toLength: maxName + 2, withPad: " ", startingAt: 0)
                let id = app.bundleIdentifier!
                let tag = config.hidden[id] != nil ? "  [managed]" : ""
                print("  \(name)\(id)\(tag)")
            }
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show managed apps.")

        func run() throws {
            let config = Config.load()

            if config.hidden.isEmpty {
                print("No managed apps.")
                return
            }

            for (bundleId, app) in config.hidden.sorted(by: { $0.value.name < $1.value.name }) {
                let running = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleId)
                let status: String
                if running.isEmpty {
                    status = "not running"
                } else if running.first!.activationPolicy == .accessory {
                    status = "pid \(running.first!.processIdentifier), hidden"
                } else {
                    status = "pid \(running.first!.processIdentifier), visible"
                }
                let name = app.name.padding(toLength: 20, withPad: " ", startingAt: 0)
                print("  \(name) \(bundleId)  [\(status)]")
            }
        }
    }

    struct Focus: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Bring a hidden app to front.")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let q = app.lowercased()
            let running = NSWorkspace.shared.runningApplications.filter {
                ($0.bundleIdentifier?.lowercased().contains(q) ?? false)
                    || ($0.localizedName?.lowercased().contains(q) ?? false)
            }

            guard let target = running.first else {
                throw GhostTileError("No running app matching '\(app)'")
            }

            target.activate(options: [.activateIgnoringOtherApps])
            print("Activated \(target.localizedName ?? target.bundleIdentifier ?? "app").")
        }
    }
}

// MARK: - Helpers

func resolveManaged(_ query: String) throws -> (String, HiddenApp) {
    let config = Config.load()
    let q = query.lowercased()

    let match = config.hidden.first {
        $0.key.lowercased().contains(q)
            || $0.value.name.lowercased().contains(q)
    }

    guard let result = match else {
        throw GhostTileError(
            "'\(query)' is not managed. Run 'ghosttile manage <app>' first.")
    }

    return result
}
