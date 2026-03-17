import AppKit
import ArgumentParser
import GhostTileCore

extension GhostTile {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List running apps.")
        @Flag(name: .long, help: "Output machine-readable JSON.") var json = false

        func run() throws {
            let snapshot = ManagedAppStateReader.makeSnapshot()
            let records = snapshot.records.sorted { $0.name < $1.name }

            if json {
                try printJSON(records)
                return
            }

            if records.isEmpty {
                print("No running apps.")
                return
            }

            let maxName = max(records.map(\.name.count).max() ?? 0, 12)

            for record in records {
                let name = record.name.padding(toLength: maxName + 2, withPad: " ", startingAt: 0)
                let tag = record.managed ? "  [managed]" : ""
                print("  \(name)\(record.bundleId)\(tag)")
            }
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show managed apps.")
        @Flag(name: .long, help: "Output machine-readable JSON.") var json = false

        func run() throws {
            let snapshot = ManagedAppStateReader.makeSnapshot()
            let records = snapshot.records
                .filter(\.managed)
                .sorted { $0.name < $1.name }

            if json {
                try printJSON(records)
                return
            }

            if records.isEmpty {
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
}
