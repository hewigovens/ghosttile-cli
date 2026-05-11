@testable import GhostTileCore
import Testing

@Suite("BuildInfo")
struct BuildInfoTests {
    @Test func appAndCLIDisplayVersionsUseIndependentComponents() {
        #expect(BuildInfo.displayVersion == "\(BuildInfo.version) (\(BuildInfo.build))")
        #expect(BuildInfo.cliDisplayVersion == "\(BuildInfo.cliVersion) (\(BuildInfo.cliBuild))")
    }
}
