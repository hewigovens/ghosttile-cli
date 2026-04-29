import XCTest

final class OnboardingFlowTests: AppUITestBase {
    func testCompletesOnboardingToMainWindow() throws {
        let app = try XCTUnwrap(app)

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10), "Onboarding Continue button did not appear")

        continueButton.click()
        XCTAssertTrue(app.staticTexts["How it works"].waitForExistence(timeout: 5), "Workflow step did not appear")

        continueButton.click()
        XCTAssertTrue(app.staticTexts["Permissions"].waitForExistence(timeout: 5), "Permissions step did not appear")
        XCTAssertTrue(
            app.descendants(matching: .any)["permissions.ghosttile.appManagement"].waitForExistence(timeout: 5),
            "GhostTile App Management permission card did not appear"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["permissions.cli.install"].waitForExistence(timeout: 5),
            "CLI install permission card did not appear"
        )

        let getStartedButton = app.buttons["onboarding.getStarted"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5), "Get Started button did not appear")
        getStartedButton.click()

        XCTAssertTrue(app.staticTexts["Managed Apps"].waitForExistence(timeout: 10), "Main window did not appear")
        XCTAssertTrue(app.buttons["Add App"].waitForExistence(timeout: 5), "Main window Add App button did not appear")
    }
}
