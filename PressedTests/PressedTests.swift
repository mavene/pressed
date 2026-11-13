import XCTest
@testable import Pressed

// Tests for the pure rules.

private let day: TimeInterval = 86_400

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func date(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = dayOfMonth
    parts.hour = hour
    parts.minute = minute
    return makeCalendar().date(from: parts)!
}

private func makeCard(title: String = "A card",
                      kind: CardKind = .article,
                      minutes: Int? = nil,
                      savedAt: Date = Date(timeIntervalSince1970: 0),
                      dueInDays: Double = 7,
                      status: CardStatus = .pending) -> CardRecord {
    CardRecord(
        id: UUID(),
        url: URL(string: "https://example.com/\(UUID().uuidString)")!,
        title: title,
        siteName: nil,
        imageData: nil,
        kind: kind,
        estMinutes: minutes,
        savedAt: savedAt,
        dueAt: savedAt.addingTimeInterval(dueInDays * day),
        status: status,
        pressedAt: nil,
        crumbledAt: nil,
        rescuedAt: nil,
        note: nil,
        finish: .none,
        sealSeed: 1)
}

// MARK: - Curl

final class CurlRulesTests: XCTestCase {
    func testLevelsFollowShareOfShelfLifeRemaining() {
        let saved = Date(timeIntervalSince1970: 0)
        let due = saved.addingTimeInterval(7 * day)
        XCTAssertEqual(CurlRules.level(savedAt: saved, dueAt: due, now: saved), 0)
        XCTAssertEqual(CurlRules.level(savedAt: saved, dueAt: due, now: saved.addingTimeInterval(3 * day)), 1)
        XCTAssertEqual(CurlRules.level(savedAt: saved, dueAt: due, now: saved.addingTimeInterval(4.5 * day)), 2)
        XCTAssertEqual(CurlRules.level(savedAt: saved, dueAt: due, now: saved.addingTimeInterval(6 * day)), 3)
    }

    func testExpiredHasNoLevel() {
        let saved = Date(timeIntervalSince1970: 0)
        let due = saved.addingTimeInterval(7 * day)
        XCTAssertNil(CurlRules.level(savedAt: saved, dueAt: due, now: due))
        XCTAssertTrue(CurlRules.isExpired(dueAt: due, now: due))
        XCTAssertFalse(CurlRules.isExpired(dueAt: due, now: due.addingTimeInterval(-1)))
    }

    func testLevelsScaleWithShelfLife() {
        let saved = Date(timeIntervalSince1970: 0)
        let due = saved.addingTimeInterval(3 * day)
        XCTAssertEqual(CurlRules.level(savedAt: saved, dueAt: due, now: saved.addingTimeInterval(2.5 * day)), 3)
    }
}

// MARK: - Due label

final class DueLabelTests: XCTestCase {
    func testTodayAndTomorrow() {
        let calendar = makeCalendar()
        let now = date(2026, 11, 3, 9)
        XCTAssertEqual(DueLabel.text(dueAt: date(2026, 11, 3, 20), now: now, calendar: calendar), "DUE TODAY")
        XCTAssertEqual(DueLabel.text(dueAt: date(2026, 11, 4, 8), now: now, calendar: calendar), "DUE TOMORROW")
    }

    func testLaterDatesStartWithDue() {
        let calendar = makeCalendar()
        let now = date(2026, 11, 3, 9)
        XCTAssertTrue(DueLabel.text(dueAt: date(2026, 11, 7), now: now, calendar: calendar).hasPrefix("DUE "))
        XCTAssertTrue(DueLabel.text(dueAt: date(2026, 11, 20), now: now, calendar: calendar).hasPrefix("DUE "))
    }
}

// MARK: - Finish

final class FinishRulesTests: XCTestCase {
    private let saved = Date(timeIntervalSince1970: 0)

    private func finish(pressedAfter days: Double, dueIn: Double = 7, minutes: Int? = nil, rescued: Bool = false) -> CardFinish {
        FinishRules.finish(
            savedAt: saved,
            pressedAt: saved.addingTimeInterval(days * day),
            dueAt: saved.addingTimeInterval(dueIn * day),
            estMinutes: minutes,
            rescued: rescued)
    }

    func testFreshWithinADay() {
        XCTAssertEqual(finish(pressedAfter: 0.5), .fresh)
    }

    func testCloseCallInLastDay() {
        XCTAssertEqual(finish(pressedAfter: 6.5), .closeCall)
    }

    func testRescued() {
        XCTAssertEqual(finish(pressedAfter: 4, rescued: true), .rescued)
    }

    func testLongReadNeedsTwentyMinutes() {
        XCTAssertEqual(finish(pressedAfter: 3, minutes: 25), .longRead)
        XCTAssertEqual(finish(pressedAfter: 3, minutes: 19), .none)
    }

    func testFreshBeatsEverythingElse() {
        XCTAssertEqual(finish(pressedAfter: 0.2, minutes: 40, rescued: true), .fresh)
    }
}

// MARK: - Kind detection

final class KindDetectorTests: XCTestCase {
    private func kind(_ string: String) -> CardKind {
        KindDetector.detect(url: URL(string: string)!)
    }

    func testHostRules() {
        XCTAssertEqual(kind("https://www.youtube.com/watch?v=abc"), .video)
        XCTAssertEqual(kind("https://youtu.be/abc"), .video)
        XCTAssertEqual(kind("https://open.spotify.com/episode/123"), .podcast)
        XCTAssertEqual(kind("https://podcasts.apple.com/us/podcast/x/id1"), .podcast)
        XCTAssertEqual(kind("https://x.com/someone/status/1"), .tweet)
    }

    func testRecipeShoppingAndPlaceLinksAreJustArticles() {
        XCTAssertEqual(kind("https://www.amazon.co.uk/dp/B000"), .article)
        XCTAssertEqual(kind("https://www.yelp.com/biz/place"), .article)
        XCTAssertEqual(kind("https://www.bbcgoodfood.com/recipes/easy-focaccia"), .article)
    }

    func testDefaultIsArticle() {
        XCTAssertEqual(kind("https://example.com/essay"), .article)
    }
}

// MARK: - Page parsing

final class PageParserTests: XCTestCase {
    private let html = """
    <html><head>
    <title>Fallback title</title>
    <meta property="og:title" content="Focaccia &amp; friends">
    <meta property="og:site_name" content="Food Blog">
    <meta property="og:image" content="/img/focaccia.jpg">
    <meta itemprop="duration" content="PT1H2M30S">
    <script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"Recipe","name":"Focaccia"}]}</script>
    </head><body><p>Short page.</p></body></html>
    """

    func testReadsTitleSiteImageAndDuration() {
        let info = PageParser.parse(html: html, base: URL(string: "https://example.com/a/b")!)
        XCTAssertEqual(info.title, "Focaccia & friends")
        XCTAssertEqual(info.siteName, "Food Blog")
        XCTAssertEqual(info.imageURL?.absoluteString, "https://example.com/img/focaccia.jpg")
        XCTAssertEqual(info.durationMinutes, 63)
        XCTAssertNil(info.readMinutes)
    }

    func testFallsBackToTitleTag() {
        let info = PageParser.parse(html: "<html><head><title> Plain </title></head></html>",
                                    base: URL(string: "https://example.com")!)
        XCTAssertEqual(info.title, "Plain")
    }

    func testReadMinutesFromWordCount() {
        let words = Array(repeating: "word", count: 660).joined(separator: " ")
        let info = PageParser.parse(html: "<html><body><p>\(words)</p></body></html>",
                                    base: URL(string: "https://example.com")!)
        XCTAssertEqual(info.readMinutes, 3)
    }

    func testIso8601Seconds() {
        XCTAssertEqual(PageParser.iso8601Seconds("PT18M30S"), 1110)
        XCTAssertNil(PageParser.iso8601Seconds("18 minutes"))
    }
}

// MARK: - Stack picker

final class StackPickerTests: XCTestCase {
    func testSoonestDueFirstAndAtMostThree() {
        let cards = (1...5).map { makeCard(title: "Card \($0)", dueInDays: Double($0)) }
        let result = StackPicker.pick(from: cards.shuffled(), budgetMinutes: nil)
        XCTAssertEqual(result.cards.map(\.title), ["Card 1", "Card 2", "Card 3"])
        XCTAssertEqual(result.totalMinutes, 30)
    }

    func testBudgetLimitsTheStack() {
        let cards = (1...4).map { makeCard(title: "Card \($0)", minutes: 10, dueInDays: Double($0)) }
        let result = StackPicker.pick(from: cards, budgetMinutes: 25)
        XCTAssertEqual(result.cards.count, 2)
        XCTAssertEqual(result.totalMinutes, 20)
    }

    func testFallsBackToMostUrgentWhenNothingFits() {
        let big = makeCard(title: "Big", minutes: 40, dueInDays: 1)
        let bigger = makeCard(title: "Bigger", minutes: 50, dueInDays: 2)
        let result = StackPicker.pick(from: [bigger, big], budgetMinutes: 5)
        XCTAssertEqual(result.cards.map(\.title), ["Big"])
    }

    func testAvoidsThreeOfTheSameKindWhenAnotherIsAvailable() {
        let videos = (1...3).map { makeCard(title: "Video \($0)", kind: .video, dueInDays: Double($0)) }
        let article = makeCard(title: "Article", kind: .article, dueInDays: 4)
        let result = StackPicker.pick(from: videos + [article], budgetMinutes: nil)
        XCTAssertEqual(result.cards.map(\.title), ["Video 1", "Video 2", "Article"])
    }

    func testEmptyPile() {
        XCTAssertEqual(StackPicker.pick(from: [], budgetMinutes: 15), StackResult(cards: [], totalMinutes: 0))
    }

    func testIgnoresCardsThatAreNotPending() {
        let pressed = makeCard(title: "Done", status: .pressed)
        XCTAssertTrue(StackPicker.pick(from: [pressed], budgetMinutes: nil).cards.isEmpty)
    }
}

// MARK: - Nudge copy and schedule

final class NudgeTests: XCTestCase {
    func testNothingWaitingMeansNoNotification() {
        XCTAssertNil(NudgeCopy.make(pending: [], fireDate: Date()))
    }

    func testCardsThatWillHaveCrumbledAreIgnored() {
        let saved = Date(timeIntervalSince1970: 0)
        let card = makeCard(savedAt: saved, dueInDays: 2)
        XCTAssertNil(NudgeCopy.make(pending: [card], fireDate: saved.addingTimeInterval(3 * day)))
    }

    func testOneCardCrumblingTomorrow() {
        let saved = Date(timeIntervalSince1970: 0)
        let card = makeCard(title: "Long read", savedAt: saved, dueInDays: 7)
        let message = NudgeCopy.make(pending: [card], fireDate: saved.addingTimeInterval(6.5 * day))
        XCTAssertEqual(message?.body, "\u{201C}Long read\u{201D} crumbles tomorrow.")
    }

    func testSeveralCardsCurling() {
        let saved = Date(timeIntervalSince1970: 0)
        let cards = (0..<3).map { _ in makeCard(savedAt: saved, dueInDays: 7) }
        let message = NudgeCopy.make(pending: cards, fireDate: saved.addingTimeInterval(4 * day))
        XCTAssertEqual(message?.body, "3 links are curling. Got 15 minutes?")
    }

    func testFreshCardsGetAGentlerLine() {
        let saved = Date(timeIntervalSince1970: 0)
        let message = NudgeCopy.make(pending: [makeCard(savedAt: saved, dueInDays: 7)],
                                     fireDate: saved.addingTimeInterval(0.5 * day))
        XCTAssertEqual(message?.body, "1 waiting in your pile. A few minutes tonight?")
    }

    func testFireDatesStartTomorrowWhenTodaysTimeHasPassed() {
        let calendar = makeCalendar()
        let now = date(2026, 11, 3, 20, 30)
        let dates = NudgeSchedule.fireDates(from: now, hour: 19, minute: 0, count: 3, calendar: calendar)
        XCTAssertEqual(dates, [date(2026, 11, 4, 19), date(2026, 11, 5, 19), date(2026, 11, 6, 19)])
    }

    func testFireDatesIncludeTodayWhenStillAhead() {
        let calendar = makeCalendar()
        let now = date(2026, 11, 3, 9)
        let dates = NudgeSchedule.fireDates(from: now, hour: 19, minute: 0, count: 2, calendar: calendar)
        XCTAssertEqual(dates.first, date(2026, 11, 3, 19))
        XCTAssertEqual(dates.count, 2)
    }
}

// MARK: - Expiry

final class ExpiryRulesTests: XCTestCase {
    func testExpiresAtEndOfLastDay() {
        let calendar = makeCalendar()
        let due = ExpiryRules.dueDate(from: date(2026, 11, 3, 9), addingDays: 7, calendar: calendar)
        XCTAssertEqual(due, date(2026, 11, 10, 23, 59).addingTimeInterval(59))
        XCTAssertFalse(CurlRules.isExpired(dueAt: due, now: date(2026, 11, 10, 20)))
        XCTAssertTrue(CurlRules.isExpired(dueAt: due, now: date(2026, 11, 11, 0, 0)))
    }

    func testRescueStaysAtEndOfDay() {
        let calendar = makeCalendar()
        let due = date(2026, 11, 10, 23, 59).addingTimeInterval(59)
        XCTAssertEqual(ExpiryRules.dueDate(from: due, addingDays: 3, calendar: calendar), date(2026, 11, 13, 23, 59).addingTimeInterval(59))
    }
}

// MARK: - Metadata retries

final class MetadataRetryPolicyTests: XCTestCase {
    private let now = date(2026, 11, 10, 12)

    func testFirstAttemptIsAlwaysAllowed() {
        XCTAssertTrue(MetadataRetryPolicy.shouldAttempt(attempts: 0, lastAttemptAt: nil, now: now))
    }

    func testRetriesWaitLongerEachTime() {
        let hour: TimeInterval = 3_600
        XCTAssertFalse(MetadataRetryPolicy.shouldAttempt(attempts: 1, lastAttemptAt: now.addingTimeInterval(-0.5 * hour), now: now))
        XCTAssertTrue(MetadataRetryPolicy.shouldAttempt(attempts: 1, lastAttemptAt: now.addingTimeInterval(-hour), now: now))
        XCTAssertFalse(MetadataRetryPolicy.shouldAttempt(attempts: 2, lastAttemptAt: now.addingTimeInterval(-5 * hour), now: now))
        XCTAssertTrue(MetadataRetryPolicy.shouldAttempt(attempts: 2, lastAttemptAt: now.addingTimeInterval(-6 * hour), now: now))
        XCTAssertFalse(MetadataRetryPolicy.shouldAttempt(attempts: 3, lastAttemptAt: now.addingTimeInterval(-23 * hour), now: now))
        XCTAssertTrue(MetadataRetryPolicy.shouldAttempt(attempts: 3, lastAttemptAt: now.addingTimeInterval(-24 * hour), now: now))
    }

    func testStopsAfterMaxAttempts() {
        let longAgo = now.addingTimeInterval(-30 * 86_400)
        XCTAssertFalse(MetadataRetryPolicy.shouldAttempt(attempts: MetadataRetryPolicy.maxAttempts, lastAttemptAt: longAgo, now: now))
        XCTAssertFalse(MetadataRetryPolicy.shouldAttempt(attempts: MetadataRetryPolicy.maxAttempts, lastAttemptAt: longAgo, now: now, ignoringWait: true))
    }

    func testIgnoringWaitSkipsOnlyTheWait() {
        XCTAssertTrue(MetadataRetryPolicy.shouldAttempt(attempts: 2, lastAttemptAt: now, now: now, ignoringWait: true))
    }
}

// MARK: - Display title

final class DisplayTitleTests: XCTestCase {
    private func record(title: String?, custom: String?) -> CardRecord {
        CardRecord(id: UUID(), url: URL(string: "https://www.example.com/a")!, title: title, siteName: nil, imageData: nil,
                   kind: .article, estMinutes: nil, savedAt: date(2026, 11, 1), dueAt: date(2026, 11, 8), status: .pending,
                   pressedAt: nil, crumbledAt: nil, rescuedAt: nil, note: nil, finish: .none, sealSeed: 0,
                   customTitle: custom)
    }

    func testCustomBeatsFetchedBeatsHost() {
        XCTAssertEqual(record(title: "Fetched", custom: "Mine").displayTitle, "Mine")
        XCTAssertEqual(record(title: "Fetched", custom: nil).displayTitle, "Fetched")
        XCTAssertEqual(record(title: "Fetched", custom: "  ").displayTitle, "Fetched")
        XCTAssertEqual(record(title: nil, custom: nil).displayTitle, "example.com")
    }

    func testFetchedTitleIgnoresCustom() {
        XCTAssertEqual(record(title: nil, custom: "Mine").fetchedTitle, "example.com")
    }
}

// MARK: - Flick physics

@MainActor
final class FlickPhysicsTests: XCTestCase {
    func testSweepSpeedRoundTripsToTheSameDistance() {
        for style in [FlickFlight.Style.lob, .classic] {
            for distance in stride(from: CGFloat(60), through: 700, by: 40) {
                let speed = FlickFlight.speed(forDistance: distance, style: style)
                XCTAssertEqual(FlickFlight.distance(forSpeed: speed, style: style), distance, accuracy: 0.01)
            }
        }
    }

    func testHarderFlicksTravelFartherButLessThanLinearly() {
        for style in [FlickFlight.Style.lob, .classic] {
            XCTAssertLessThan(FlickFlight.distance(forSpeed: 1200, style: style), FlickFlight.distance(forSpeed: 2000, style: style))
            let capped = FlickFlight.distance(forSpeed: 4400, style: style)
            XCTAssertLessThan(capped, 4400 * FlickFlight.reach(style))
        }
    }

    func testFireplaceKeepsTheOriginalFeel() {
        XCTAssertEqual(FlickFlight.reach(.classic), 0.14)
        XCTAssertEqual(FlickMath.minimumThrowSpeed(.classic), 220)
        XCTAssertGreaterThan(FlickMath.minimumThrowSpeed(.lob), FlickMath.minimumThrowSpeed(.classic))
    }
}
