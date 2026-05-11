@testable import GhostTileCore
import Testing

@Suite("ManagedAppStateReader")
struct ManagedAppStateReaderTests {
    @Test func sortedRecordsUsesStableNameBundleAndPathOrder() {
        let records = [
            record(name: "WeChat", bundleId: "com.tencent.xinWeChat", appPath: "/Applications/WeChat.app"),
            record(name: "LocalSend", bundleId: "org.localsend.localsend", appPath: "/Applications/LocalSend.app"),
            record(name: "LocalSend", bundleId: "org.localsend.beta", appPath: "/Applications/LocalSend Beta.app"),
            record(name: "LocalSend", bundleId: "org.localsend.beta", appPath: "/Users/me/LocalSend Beta.app"),
        ]

        let sorted = ManagedAppStateReader.sortedRecords(records)

        #expect(sorted.map(\.appPath) == [
            "/Applications/LocalSend Beta.app",
            "/Users/me/LocalSend Beta.app",
            "/Applications/LocalSend.app",
            "/Applications/WeChat.app",
        ])
    }

    private func record(name: String, bundleId: String, appPath: String) -> ManagedAppRecord {
        ManagedAppRecord(
            bundleId: bundleId,
            name: name,
            appPath: appPath,
            binaryPath: "\(appPath)/Contents/MacOS/\(name)",
            managed: true,
            running: false,
            hiddenFromDock: true,
            pid: nil,
            isSIPProtected: false,
            categoryIdentifier: nil
        )
    }
}
