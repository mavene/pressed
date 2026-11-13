import XCTest

/// Read a link, come back, press it: Pile to Shelf.
final class PressFlowUITests: PressedUITestCase {
    func testPressingACardMovesItFromThePileToTheShelf() {
        launch()
        assertExists(pileSubtitle(seedCount))

        readAndPress(UITestSeed.article.title, note: "Paper has a long story")

        assertExists(pileSubtitle(seedCount - 1), "The pile should have one fewer card")
        assertGone(pileCard(UITestSeed.article.title))

        openTab("The Shelf")
        assertExists(shelfSubtitle(pressed: 1))
        assertExists(element(labelStartingWith: UITestSeed.article.title), "The bookmark is not on the Shelf")
    }

    func testATypedTitleReplacesTheFetchedOneOnTheShelf() {
        launch()
        readAndPress(UITestSeed.video.title, pressedTitle: "Binding, explained", note: nil)

        openTab("The Shelf")
        assertExists(element(labelStartingWith: "Binding, explained"))
        XCTAssertFalse(element(labelStartingWith: UITestSeed.video.title).exists,
                       "The fetched title should be replaced by the typed one")
    }

    func testPressWithoutANoteWorks() {
        launch()
        readAndReturn(UITestSeed.podcast.title)

        let withoutNote = app.buttons["Press without a note"]
        assertExists(withoutNote)
        withoutNote.tap()

        assertGone(pressSheetHeadline, timeout: slow)
        assertExists(pileSubtitle(seedCount - 1))
    }

    func testNotYetLeavesTheCardWaiting() {
        launch()
        readAndReturn(UITestSeed.post.title)

        app.buttons["Not yet"].tap()

        assertGone(pressSheetHeadline)
        assertExists(pileSubtitle(seedCount), "Nothing should have been pressed")
        XCTAssertTrue(pileCard(UITestSeed.post.title).exists || scrollToPileCard(UITestSeed.post.title).exists)
        XCTAssertFalse(pressedToast.exists)
    }

    func testAQuickTapOnPressDoesNothingBecauseItMustBeHeld() {
        launch()
        readAndReturn(UITestSeed.article.title)

        holdToPressButton.press(forDuration: 0.2)

        // Give a (wrongly) completed press time to finish its animation and close the sheet.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(pressSheetHeadline.exists, "A short tap must not press the card")
        XCTAssertFalse(pressedToast.exists)

        app.buttons["Not yet"].tap()
        assertExists(pileSubtitle(seedCount))
    }

    func testAPressedCardCanNoLongerBeOpenedFromThePile() {
        launch()
        readAndPress(UITestSeed.article.title)

        assertGone(pileCard(UITestSeed.article.title))
        XCTAssertEqual(app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", UITestSeed.article.title)).count, 0)
    }

    func testPressingSeveralCardsFillsTheShelfInOrder() {
        launch()
        readAndPress(UITestSeed.article.title)
        assertExists(pileSubtitle(seedCount - 1))

        readAndPress(UITestSeed.video.title)
        assertExists(pileSubtitle(seedCount - 2))

        openTab("The Shelf")
        assertExists(shelfSubtitle(pressed: 2))
        assertExists(element(labelStartingWith: UITestSeed.article.title))
        assertExists(element(labelStartingWith: UITestSeed.video.title))
    }
}
