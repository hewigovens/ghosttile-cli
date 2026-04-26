@testable import GhostTileCore
import XCTest

final class BuildInfoTests: XCTestCase {
    func testAppAndCLIDisplayVersionsUseIndependentComponents() {
        XCTAssertEqual(BuildInfo.displayVersion, "\(BuildInfo.version) (\(BuildInfo.build))")
        XCTAssertEqual(BuildInfo.cliDisplayVersion, "\(BuildInfo.cliVersion) (\(BuildInfo.cliBuild))")
    }
}
