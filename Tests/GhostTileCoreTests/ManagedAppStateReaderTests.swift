@testable import GhostTileCore
import XCTest

final class ManagedAppStateReaderTests: XCTestCase {
    func testSortedRecordsUsesStableNameBundleAndPathOrder() {
        let records = [
            record(name: "WeChat", bundleId: "com.tencent.xinWeChat", appPath: "/Applications/WeChat.app"),
            record(name: "LocalSend", bundleId: "org.localsend.localsend", appPath: "/Applications/LocalSend.app"),
            record(name: "LocalSend", bundleId: "org.localsend.beta", appPath: "/Applications/LocalSend Beta.app"),
            record(name: "LocalSend", bundleId: "org.localsend.beta", appPath: "/Users/me/LocalSend Beta.app"),
        ]

        let sorted = ManagedAppStateReader.sortedRecords(records)

        XCTAssertEqual(sorted.map(\.appPath), [
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
