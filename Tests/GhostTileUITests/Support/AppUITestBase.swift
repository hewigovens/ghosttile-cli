import GhostTileCore
import XCTest

class AppUITestBase: XCTestCase {
    var app: XCUIApplication?
    private var defaultsSuiteName: String?
    private var defaults: UserDefaults?

    override func setUpWithError() throws {
        continueAfterFailure = false
        let defaultsSuiteName = "\(AppConstants.bundleIdentifier).uitests.\(UUID().uuidString)"
        self.defaultsSuiteName = defaultsSuiteName
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        configureTestDefaults()

        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            AppConstants.defaultsSuiteLaunchArgument, defaultsSuiteName,
        ]
        app.launch()

        self.app = app
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10), "GhostTile window did not appear")
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        removeTestDefaults()
    }

    private func configureTestDefaults() {
        guard let defaults, let defaultsSuiteName else { return }

        var domain = defaults.persistentDomain(forName: defaultsSuiteName) ?? [:]
        domain["onboardingComplete"] = false
        domain["showInDock"] = true
        domain["sponsorNudgeOptedOut"] = true
        domain.removeValue(forKey: "sponsorNudgeUsageCount")
        defaults.setPersistentDomain(domain, forName: defaultsSuiteName)
    }

    private func removeTestDefaults() {
        guard let defaults, let defaultsSuiteName else { return }

        defaults.removePersistentDomain(forName: defaultsSuiteName)
        self.defaults = nil
        self.defaultsSuiteName = nil
    }
}
