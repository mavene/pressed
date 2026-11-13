import XCTest

/// Every kind of link (article, video, podcast, post) through the Pile, the reader,
/// the press sheet and the Shelf.
final class CardTypesUITests: PressedUITestCase {
    func testEveryKindAppearsOnThePileWithItsLabelAndTime() {
        launch()
        assertExists(pileSubtitle(UITestSeed.all.count))

        for seed in UITestSeed.all {
            let card = scrollToPileCard(seed.title)
            XCTAssertTrue(card.label.lowercased().contains(seed.detail),
                          "“\(seed.title)” should read as “\(seed.detail)”, got: \(card.label)")
        }
    }

    func testPileIsOrderedMostCurledFirst() {
        launch()
        let first = app.cells.element(boundBy: 0)
        assertExists(first)
        XCTAssertTrue(first.label.hasPrefix(UITestSeed.article.title),
                      "The oldest save should lead, got: \(first.label)")
    }

    func testEveryKindOpensTheReaderAndThenOffersToPress() {
        launch()
        for seed in UITestSeed.all {
            openFromPile(seed.title)
            closeReader()
            assertExists(pressSheetHeadline, "No press sheet after reading the \(seed.kind)")
            app.buttons["Not yet"].tap()
            assertGone(pressSheetHeadline)
        }
        assertExists(pileSubtitle(UITestSeed.all.count), "Reading without pressing must not remove anything")
    }

    func testPressingAVideoAndAPodcastKeepsTheirKindOnTheShelf() {
        launch()
        readAndPress(UITestSeed.video.title)
        readAndPress(UITestSeed.podcast.title)

        openTab("The Shelf")
        assertExists(shelfSubtitle(pressed: 2))
        let video = element(labelStartingWith: UITestSeed.video.title)
        let podcast = element(labelStartingWith: UITestSeed.podcast.title)
        assertExists(video)
        assertExists(podcast)
        XCTAssertTrue(video.label.contains("video"), video.label)
        XCTAssertTrue(podcast.label.contains("podcast"), podcast.label)
    }

    func testPressSheetShowsThePreviewOfTheCardBeingPressed() {
        launch()
        readAndReturn(UITestSeed.podcast.title)

        // The same card is drawn at the top of the sheet.
        assertExists(app.staticTexts[UITestSeed.podcast.title])
        assertExists(app.staticTexts["PODCAST \u{00B7} 25 MIN"])
        app.buttons["Not yet"].tap()
    }

    func testLettingAGoOfACardCrumblesItIntoTheShelfCount() {
        launch()
        let card = scrollToPileCard(UITestSeed.all.last!.title)
        card.swipeLeft()
        let letGo = app.buttons["Let go"]
        assertExists(letGo)
        letGo.tap()

        assertExists(pileSubtitle(UITestSeed.all.count - 1), timeout: slow)
        openTab("The Shelf")
        assertExists(shelfSubtitle(pressed: 0, crumbled: 1))
    }
}
