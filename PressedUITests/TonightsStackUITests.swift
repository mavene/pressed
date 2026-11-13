import XCTest

/// Tonight's Stack: up to three cards, chosen by due date and the time the reader has.
/// The numbers follow from the seed: article 4 min, video 12, podcast 25, everything else the default 10.
final class TonightsStackUITests: PressedUITestCase {
    private var stackTitle: XCUIElement { app.staticTexts["Tonight\u{2019}s stack"] }

    private func openStack() {
        let button = app.buttons["Tonight\u{2019}s stack"]
        assertExists(button)
        button.tap()
        assertExists(stackTitle)
    }

    private func stackSubtitle(_ text: String) -> XCUIElement { app.staticTexts[text] }

    private func chooseBudget(_ title: String) {
        let segment = app.segmentedControls.buttons[title]
        assertExists(segment)
        segment.tap()
    }

    private func stackCard(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    func testStackOffersTheThreeMostUrgentCards() {
        launch()
        openStack()

        assertExists(stackSubtitle("3 cards \u{00B7} about 41 min"))
        assertExists(stackCard(UITestSeed.article.title))
        assertExists(stackCard(UITestSeed.video.title))
        assertExists(stackCard(UITestSeed.podcast.title))
        XCTAssertFalse(stackCard(UITestSeed.post.title).exists, "Only three cards fit in a stack")
    }

    func testEachTimeBudgetPicksWhatFits() {
        launch()
        openStack()

        chooseBudget("5 min")
        assertExists(stackSubtitle("1 card \u{00B7} about 4 min"))
        assertExists(stackCard(UITestSeed.article.title))
        XCTAssertFalse(stackCard(UITestSeed.video.title).exists)

        chooseBudget("15 min")
        assertExists(stackSubtitle("2 cards \u{00B7} about 14 min"))
        assertExists(stackCard(UITestSeed.post.title), "The 12 min video does not fit next to the article")
        XCTAssertFalse(stackCard(UITestSeed.video.title).exists)

        chooseBudget("30 min")
        assertExists(stackSubtitle("3 cards \u{00B7} about 26 min"))

        chooseBudget("Any")
        assertExists(stackSubtitle("3 cards \u{00B7} about 41 min"))
    }

    func testReadingAndPressingFromTheStackTakesTheCardOffIt() {
        launch()
        openStack()

        stackCard(UITestSeed.article.title).tap()
        assertExists(readerDoneButton, "The reader did not open", timeout: slow)
        closeReader()
        assertExists(pressSheetHeadline)
        holdToPress(note: "Read tonight")
        assertGone(pressSheetHeadline, timeout: slow)

        // The stack is still on screen and refills with the next most urgent card.
        assertGone(stackCard(UITestSeed.article.title))
        assertExists(stackSubtitle("3 cards \u{00B7} about 47 min"))
        assertExists(stackCard(UITestSeed.post.title))
    }

    func testCloseReturnsToThePile() {
        launch()
        openStack()
        app.buttons["Close"].tap()
        assertGone(stackTitle)
        assertExists(pileSubtitle(UITestSeed.all.count))
    }

    func testEmptyPileSaysSoAndHidesTheTimePicker() {
        launch(seeded: false)
        assertExists(app.staticTexts["nothing waiting"])
        openStack()

        assertExists(stackSubtitle("nothing waiting"))
        assertExists(app.staticTexts["Nothing waiting, do you even read?"])
        XCTAssertFalse(app.segmentedControls.firstMatch.isHittable, "No time picker without cards")
    }

    func testStackIsReachableFromTheEveningNotificationRoute() {
        launch()
        // The same deep link a notification tap uses.
        XCUIDevice.shared.system.open(URL(string: "pressed://stack")!)
        assertExists(stackTitle, timeout: slow)
    }
}
