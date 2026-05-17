@testable import GhostTileApp
import Testing

@Suite("AppManagementPermissionStatusReader")
struct AppManagementPermissionStatusReaderTests {
    @Test func preflightResultZeroMeansAllowed() {
        #expect(AppManagementPermissionStatusReader.isAllowed(preflightResult: 0))
    }

    @Test func nonZeroPreflightResultsAreNotAllowed() {
        #expect(!AppManagementPermissionStatusReader.isAllowed(preflightResult: 1))
        #expect(!AppManagementPermissionStatusReader.isAllowed(preflightResult: 2))
    }
}
