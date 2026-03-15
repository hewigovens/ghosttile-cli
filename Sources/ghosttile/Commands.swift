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
            let dylibPath = try Dylib.ensureDylib()
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

            let shouldPrepare: Bool
            if forcePrepare {
                shouldPrepare = true
            } else {
                shouldPrepare = try AppManager.needsPreparation(resolved)
            }
            if shouldPrepare {
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

            let shouldPrepare: Bool
            if force {
                shouldPrepare = true
            } else {
                shouldPrepare = try AppManager.needsPreparation(resolved)
            }

            guard shouldPrepare else {
                print("\(resolved.name) is already prepared.")
                return
            }

            print("Preparing \(resolved.name)...")
            try AppManager.prepare(resolved)
            print("\(resolved.name) prepared. No relaunch performed.")
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
            if !running.isEmpty {
                try AppManager.launchNormal(hiddenApp.appPath)
                print("\(hiddenApp.name) restored and visible in Dock.")
            } else {
                print("\(hiddenApp.name) restored.")
            }
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

            ManagedAppNotifications.post(bundleId: bundleId, action: .hide)
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

            ManagedAppNotifications.post(bundleId: bundleId, action: .show)
            print("\(hiddenApp.name) shown in Dock.")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List running apps.")
        @Flag(name: .long, help: "Output machine-readable JSON.") var json = false

        func run() throws {
            let config = Config.load()
            let apps =
                NSWorkspace.shared.runningApplications
                .filter { app in
                    guard let bundleId = app.bundleIdentifier else { return false }
                    return app.activationPolicy == .regular
                        || config.hidden[bundleId] != nil
                }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

            let records = apps.compactMap { app -> CLIAppRecord? in
                guard let bundleId = app.bundleIdentifier,
                      let info = try? AppManager.info(from: app)
                else { return nil }

                return CLIAppRecord(
                    bundleId: bundleId,
                    name: info.name,
                    appPath: info.appPath,
                    binaryPath: info.binaryPath,
                    managed: config.hidden[bundleId] != nil,
                    running: true,
                    hiddenFromDock: app.activationPolicy == .accessory,
                    pid: app.processIdentifier
                )
            }

            if json {
                try printJSON(records)
                return
            }

            if apps.isEmpty {
                print("No running apps.")
                return
            }

            let maxName = max(apps.map { ($0.localizedName ?? "").count }.max() ?? 0, 12)

            for app in apps {
                guard let id = app.bundleIdentifier else { continue }
                let name =
                    (app.localizedName ?? "Unknown")
                    .padding(toLength: maxName + 2, withPad: " ", startingAt: 0)
                let tag = config.hidden[id] != nil ? "  [managed]" : ""
                print("  \(name)\(id)\(tag)")
            }
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show managed apps.")
        @Flag(name: .long, help: "Output machine-readable JSON.") var json = false

        func run() throws {
            let config = Config.load()

            let records = config.hidden.sorted(by: { $0.value.name < $1.value.name }).map {
                bundleId, app in
                let running = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleId)
                let process = running.first
                return CLIAppRecord(
                    bundleId: bundleId,
                    name: app.name,
                    appPath: app.appPath,
                    binaryPath: app.binaryPath,
                    managed: true,
                    running: process != nil,
                    hiddenFromDock: process?.activationPolicy == .accessory,
                    pid: process?.processIdentifier
                )
            }

            if json {
                try printJSON(records)
                return
            }

            if config.hidden.isEmpty {
                print("No managed apps.")
                return
            }

            for record in records {
                let status: String
                if let pid = record.pid {
                    status = record.hiddenFromDock ? "pid \(pid), hidden" : "pid \(pid), visible"
                } else {
                    status = "not running"
                }
                let name = record.name.padding(toLength: 20, withPad: " ", startingAt: 0)
                print("  \(name) \(record.bundleId)  [\(status)]")
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

            target.activate()
            print("Activated \(target.localizedName ?? target.bundleIdentifier ?? "app").")
        }
    }
}

private struct CLIAppRecord: Encodable {
    let bundleId: String
    let name: String
    let appPath: String
    let binaryPath: String
    let managed: Bool
    let running: Bool
    let hiddenFromDock: Bool
    let pid: pid_t?
}

private func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    if let output = String(data: data, encoding: .utf8) {
        print(output)
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
