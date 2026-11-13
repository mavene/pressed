import XCTest

/// The three first-launch pages: the message, and getting out of them.
final class OnboardingUITests: PressedUITestCase {
    private let pages = [
        "Read it or lose it.",
        "Read one and press it flat to keep it forever.",
        "Wait too long and it's toast."
    ]

    func testPagesTellTheStoryInOrderAndLeadToThePile() {
        launch(seeded: false, onboarding: true)

        assertExists(app.staticTexts[pages[0]])
        app.buttons["Next"].tap()
        assertExists(app.staticTexts[pages[1]])
        app.buttons["Next"].tap()
        assertExists(app.staticTexts[pages[2]])

        let start = app.buttons["Get started"]
        assertExists(start, "The last page should say “Get started”")
        start.tap()

        assertExists(app.staticTexts["The Pile"])
        assertExists(app.staticTexts["nothing waiting"])
    }

    func testFirstPageExplainsHowToSaveALink() {
        launch(seeded: false, onboarding: true)
        let body = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Tap Share, pick Pressed'")).firstMatch
        assertExists(body, "The share steps belong on the first page")
        XCTAssertTrue(body.label.contains("Pile"))
    }

    func testLastPageSaysHowLongALinkLasts() {
        launch(seeded: false, onboarding: true)
        app.buttons["Next"].tap()
        app.buttons["Next"].tap()
        let body = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '3, 7 or 14 days'")).firstMatch
        assertExists(body)
    }

    func testSkipGoesStraightToThePile() {
        launch(seeded: false, onboarding: true)
        let skip = app.buttons["Skip"]
        assertExists(skip)
        skip.tap()
        assertExists(app.staticTexts["The Pile"])
    }

    func testOnboardingIsNotShownAgainOnceFinished() {
        launch(seeded: false)   // the hook marks onboarding as done
        assertExists(app.staticTexts["The Pile"])
        XCTAssertFalse(app.buttons["Get started"].exists)
    }
}
