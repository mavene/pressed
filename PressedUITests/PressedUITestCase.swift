import XCTest

/// Mirrors `UITestSupport.seedCards` in the app: one pending card of every kind, most curled first.
/// Titles and the text the pile shows for each card (`label`) must stay in step with that list.
struct UITestSeed {
    let title: String
    let kind: String      // as spoken, e.g. "video"
    let detail: String    // the kind line as spoken, e.g. "video · 12 min"

    static let all: [UITestSeed] = [
        UITestSeed(title: "7 Short Novels for People Who Say They Don’t Have Time to Read", kind: "article", detail: "article · 4 min"),
        UITestSeed(title: "Why everyone stopped reading.", kind: "video", detail: "video · 12 min"),
        UITestSeed(title: "What Should I Read Next?", kind: "podcast", detail: "podcast · 25 min"),
        UITestSeed(title: "The Book Riot Podcast on Bluesky", kind: "post", detail: "post")
    ]

    static let article = all[0]
    static let video = all[1]
    static let podcast = all[2]
    static let post = all[3]
}

/// Base class: launches the app in a clean, seeded state and offers helpers for the flows the tests share.
///
/// Run these on a simulator that has only the test build installed. A second copy of Pressed (for example one
/// built with the real bundle ID) also registers the "Pressed" share extension and the `pressed://` link scheme,
/// so the Safari share test and the stack deep-link test can end up talking to the other app.
class PressedUITestCase: XCTestCase {
    let app = XCUIApplication()

    /// Safari's in-app reader needs the network to show a page; its Done button does not.
    var seedCount: Int { UITestSeed.all.count }

    let slow: TimeInterval = 15
    let quick: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// - Parameters:
    ///   - seeded: start with one pending card of every kind.
    ///   - onboarding: show the first-launch pages instead of skipping them.
    ///   - sharing: a link to queue exactly as the share extension would.
    func launch(seeded: Bool = true, onboarding: Bool = false, sharing link: String? = nil) {
        var arguments = ["-uitest"]
        if seeded { arguments.append("-uitest-seed") }
        if onboarding { arguments.append("-uitest-onboarding") }
        if let link { arguments += ["-uitest-share", link] }
        app.launchArguments = arguments
        app.launch()
    }

    // MARK: Finding things

    /// Any element whose accessibility label starts with `prefix`.
    func element(labelStartingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            .firstMatch
    }

    func pileCard(_ title: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// The Pile only builds the cards on screen, so swipe until the one we want exists.
    @discardableResult
    func scrollToPileCard(_ title: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let card = pileCard(title)
        var swipes = 0
        while !card.waitForExistence(timeout: 1) && swipes < 6 {
            app.collectionViews.firstMatch.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(card.exists, "No card titled “\(title)” on the Pile", file: file, line: line)
        return card
    }

    func pileSubtitle(_ count: Int) -> XCUIElement {
        app.staticTexts["\(count) waiting \u{00B7} most curled first"]
    }

    func shelfSubtitle(pressed: Int, crumbled: Int = 0) -> XCUIElement {
        app.staticTexts["\(pressed) pressed \u{00B7} \(crumbled) crumbled"]
    }

    func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: quick), "No “\(name)” tab")
        tab.tap()
    }

    // MARK: Waiting

    func assertExists(_ element: XCUIElement, _ message: String = "",
                      timeout: TimeInterval? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let found = element.waitForExistence(timeout: timeout ?? quick)
        if !found { holdScreenForInspection() }
        XCTAssertTrue(found, message.isEmpty ? "Expected \(element) to appear" : message, file: file, line: line)
    }

    /// Debugging aid: run with TEST_RUNNER_UITEST_PAUSE_ON_FAILURE=<seconds> and the simulator stays put on the
    /// screen where an expectation failed, so it can be looked at.
    func holdScreenForInspection() {
        guard let text = ProcessInfo.processInfo.environment["UITEST_PAUSE_ON_FAILURE"],
              let seconds = TimeInterval(text) else { return }
        print("PAUSED-FOR-INSPECTION")
        Thread.sleep(forTimeInterval: seconds)
    }

    func assertGone(_ element: XCUIElement, _ message: String = "",
                    timeout: TimeInterval? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout ?? quick), .completed,
                       message.isEmpty ? "Expected \(element) to go away" : message, file: file, line: line)
    }

    // MARK: Reading and pressing

    /// Taps a card on the Pile, which opens the link in Safari's in-app reader.
    func openFromPile(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        scrollToPileCard(title, file: file, line: line).tap()
        assertExists(readerDoneButton, "The reader did not open", timeout: slow, file: file, line: line)
    }

    var readerDoneButton: XCUIElement { app.buttons["Done"] }

    /// Taps Done until the reader goes away. Safari's chrome can swallow the first tap while it is still
    /// settling after the page loads.
    func closeReader(file: StaticString = #filePath, line: UInt = #line) {
        assertExists(readerDoneButton, "The reader is not open", timeout: slow, file: file, line: line)
        for attempt in 0..<4 {
            guard readerDoneButton.exists else { return }
            // A plain tap is sometimes ignored by the remote Safari view; fall back to a coordinate press.
            if attempt % 2 == 0 {
                readerDoneButton.tap()
            } else {
                readerDoneButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.15)
            }
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: readerDoneButton)
            if XCTWaiter().wait(for: [gone], timeout: 2) == .completed { return }
        }
        XCTFail("The reader did not close", file: file, line: line)
    }

    var pressSheetHeadline: XCUIElement { app.staticTexts["Finished? Press it."] }
    var holdToPressButton: XCUIElement { app.buttons["Press"] }
    var pressedToast: XCUIElement { app.staticTexts["Pressed. It\u{2019}s on your Shelf."] }

    /// Open a card, close the reader and wait for the press sheet.
    func readAndReturn(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        openFromPile(title, file: file, line: line)
        closeReader(file: file, line: line)
        assertExists(pressSheetHeadline, "The press sheet did not appear", file: file, line: line)
    }

    /// Fills in the optional fields on the press sheet, then holds the button until the seal drops.
    func holdToPress(title: String? = nil, note: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        if let title {
            let field = app.textFields["Title"]
            assertExists(field, file: file, line: line)
            field.tap()
            field.typeText(title + "\n")        // Return moves on to the note field
        }
        if let note {
            let field = app.textFields["What stuck with you?"]
            assertExists(field, file: file, line: line)
            field.tap()
            field.typeText(note + "\n")         // Return closes the keyboard
        }
        assertExists(holdToPressButton, file: file, line: line)
        holdToPressButton.press(forDuration: 1.5)
    }

    /// The whole flow: open, read, come back, press.
    func readAndPress(_ title: String, pressedTitle: String? = nil, note: String? = nil,
                      file: StaticString = #filePath, line: UInt = #line) {
        readAndReturn(title, file: file, line: line)
        holdToPress(title: pressedTitle, note: note, file: file, line: line)
        // The toast is not checked: it fades in 2.5 s and XCUITest, which waits for the app's animations to settle,
        // usually looks only after it has gone. Success is the sheet closing; callers then check the Pile and Shelf.
        assertGone(pressSheetHeadline, "The press sheet did not close", timeout: slow, file: file, line: line)
    }
}
