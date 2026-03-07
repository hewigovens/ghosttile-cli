import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
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
                let tag = config.hidden[id] != nil ? "  [hidden]" : ""
                print("  \(name)\(id)\(tag)")
            }
        }
    }

    struct Hide: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Hide an app from Dock and Cmd+Tab.")
        @Argument(help: "Bundle ID or app name.") var app: String

        func run() throws {
            let dylibPath = try Dylib.ensureCompiled()
            let resolved = try AppManager.resolve(app)
            let config = Config.load()

            // Already hidden?
            if config.hidden[resolved.bundleId] != nil {
                let running = NSRunningApplication.runningApplications(
                    withBundleIdentifier: resolved.bundleId)
                if running.first?.activationPolicy == .accessory {
                    print("\(resolved.name) is already hidden.")
                    return
                }
            }

            if AppManager.isSIPProtected(resolved.appPath) {
                throw GhostTileError(
                    "\(resolved.name) is in a SIP-protected location.")
            }

            // Re-sign if needed
            if try AppManager.needsPreparation(resolved) {
                print("Preparing \(resolved.name)...")
                try AppManager.prepare(resolved)
            }

            // Restart hidden
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

            // Verify
            Thread.sleep(forTimeInterval: 2)
            let launched = NSRunningApplication.runningApplications(
                withBundleIdentifier: resolved.bundleId)
            if launched.first?.activationPolicy == .accessory {
                print("\(resolved.name) is now hidden from Dock and Cmd+Tab.")
            } else if launched.isEmpty {
                print(
                    "Warning: \(resolved.name) may not have launched. Check 'ghosttile status'.")
            } else {
                print(
                    "Warning: \(resolved.name) launched but the app may override its activation policy."
                )
            }
        }
    }

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Unhide an app (restore to Dock).")
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
                    "'\(app)' is not hidden. Run 'ghosttile status' to see hidden apps.")
            }

            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId)
            if !running.isEmpty {
                print("Restarting \(hiddenApp.name)...")
                try AppManager.quit(bundleId)
            }

            print("Restoring original binary...")
            try AppManager.restoreBinary(bundleId, binaryPath: hiddenApp.binaryPath, appPath: hiddenApp.appPath)
            try Config.removeHidden(bundleId)
            try AppManager.launchNormal(hiddenApp.appPath)
            print("\(hiddenApp.name) is now visible in Dock.")
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show hidden apps.")

        func run() throws {
            let config = Config.load()

            if config.hidden.isEmpty {
                print("No hidden apps.")
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
                    status = "pid \(running.first!.processIdentifier), visible (re-hide needed)"
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

    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Compile the injection dylib.")

        func run() throws {
            print("Compiling ghosthide.dylib...")
            let path = try Dylib.compile()
            print("Installed to \(path)")
        }
    }
}
