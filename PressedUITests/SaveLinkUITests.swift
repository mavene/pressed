import XCTest

/// Saving a link. The first test replays what the share extension leaves behind; the second drives the real
/// thing, from Safari's Share button.
final class SaveLinkUITests: PressedUITestCase {
    private let link = "https://example.com/uitest-article"

    /// A fresh save shows its host until the page title is fetched, then the title.
    private var savedCard: XCUIElement {
        app.cells.matching(NSPredicate(format: "label BEGINSWITH 'example.com' OR label BEGINSWITH 'Example Domain'"))
            .firstMatch
    }

    func testALinkLeftByTheShareExtensionAppearsOnThePile() {
        launch(seeded: false, sharing: link)

        assertExists(savedCard, "The shared link never reached the Pile", timeout: slow)
        assertExists(pileSubtitle(1))
        XCTAssertTrue(savedCard.label.contains("article"), "A plain page is an article: \(savedCard.label)")
    }

    func testSavedLinkLandsAtTheBottomOfASeededPile() {
        launch(seeded: true, sharing: link)

        assertExists(pileSubtitle(UITestSeed.all.count + 1), timeout: slow)
        let first = app.cells.element(boundBy: 0)
        XCTAssertTrue(first.label.hasPrefix(UITestSeed.article.title), "A new save is the least curled, so it goes last")
    }

    func testEmptyPileOffersAHowToSaveGuide() {
        launch(seeded: false)

        assertExists(app.staticTexts["Nothing waiting"])
        let guide = app.buttons["How to save a link"]
        assertExists(guide)
        guide.tap()

        assertExists(app.staticTexts["Saving a link"])
        assertExists(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'tap the Share button'")).firstMatch)
    }

    // MARK: Through Safari

    /// Opens a page in Safari, taps Share, picks Pressed, then comes back to the app.
    /// This depends on Safari's and the share sheet's own layout, which Apple changes between releases, so
    /// when it cannot find a control it says which one instead of failing quietly.
    func testSavingAPageFromSafariThroughTheShareSheet() throws {
        launch(seeded: false)
        assertExists(app.staticTexts["Nothing waiting"])

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        try open("https://example.com/", in: safari)
        try tapShare(in: safari)
        try chooseShareTarget("Pressed", in: safari)

        let saved = safari.staticTexts["Saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: slow), "The share extension never said “Saved”")

        app.activate()
        assertExists(savedCard, "The page saved from Safari did not reach the Pile", timeout: slow)
        assertExists(pileSubtitle(1))
    }

    private func open(_ address: String, in safari: XCUIApplication) throws {
        let candidates = [safari.buttons["Address"], safari.textFields["Address"],
                          safari.otherElements["Address"], safari.buttons["URL"], safari.textFields["URL"]]
        guard let bar = candidates.first(where: { $0.waitForExistence(timeout: 3) }) else {
            throw XCTSkip("Could not find Safari's address bar. Update `open(_:in:)` for this iOS version.")
        }
        bar.tap()
        let field = safari.textFields["Address"].exists ? safari.textFields["Address"] : safari.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: quick), "Safari's address field did not open")
        field.typeText(address + "\n")
    }

    /// Older Safari has a Share button in its toolbar; on iOS 26 the bottom bar only has More, and Share is in
    /// its menu.
    private func tapShare(in safari: XCUIApplication) throws {
        func shareControl() -> XCUIElement? {
            [safari.buttons["Share"], safari.menuItems["Share"], safari.cells["Share"]]
                .first { $0.exists }
        }

        if shareControl() == nil {
            let more = safari.buttons["More"]
            guard more.waitForExistence(timeout: slow) else {
                print("DEBUG-SAFARI-TREE:\n" + safari.debugDescription)
                holdScreenForInspection()
                throw XCTSkip("Could not find Safari's Share or More button. Update `tapShare(in:)` for this iOS version.")
            }
            // Like the reader's Done button, Safari's glass buttons sometimes ignore the first tap.
            for attempt in 0..<4 where shareControl() == nil {
                if attempt % 2 == 0 {
                    more.tap()
                } else {
                    more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.15)
                }
                let deadline = Date().addingTimeInterval(2)
                while shareControl() == nil, Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
            }
        }

        guard let share = shareControl() else {
            print("DEBUG-SAFARI-TREE:\n" + safari.debugDescription)
            holdScreenForInspection()
            throw XCTSkip("Safari's More menu has no Share item. Update `tapShare(in:)` for this iOS version.")
        }
        share.tap()
    }

    /// The target is in the row of apps, or behind More the first time Pressed is used.
    private func chooseShareTarget(_ name: String, in safari: XCUIApplication) throws {
        let sheet = safari.otherElements["ActivityListView"]
        if !sheet.waitForExistence(timeout: slow) {
            print("DEBUG-SAFARI-TREE:\n" + safari.debugDescription)
            holdScreenForInspection()
        }
        XCTAssertTrue(sheet.exists, "The share sheet did not open")

        func target() -> XCUIElement {
            let predicate = NSPredicate(format: "label == %@", name)
            let inRow = safari.collectionViews.cells.matching(predicate).firstMatch
            return inRow.exists ? inRow : safari.buttons.matching(predicate).firstMatch
        }

        if target().waitForExistence(timeout: 3) {
            target().tap()
            return
        }

        // Scroll the app row sideways, then fall back to More.
        for _ in 0..<3 where !target().exists {
            sheet.swipeLeft()
        }
        if target().exists {
            target().tap()
            return
        }

        let more = safari.buttons["More"]
        guard more.exists else {
            throw XCTSkip("“\(name)” is not in the share sheet and there is no More button. Is the share extension installed?")
        }
        more.tap()
        let toggle = safari.switches[name]
        guard toggle.waitForExistence(timeout: quick) else {
            throw XCTSkip("“\(name)” is not offered under More. Is the share extension installed?")
        }
        if toggle.value as? String != "1" { toggle.tap() }
        safari.buttons["Done"].tap()
        XCTAssertTrue(target().waitForExistence(timeout: quick), "“\(name)” did not appear after being switched on")
        target().tap()
    }
}
