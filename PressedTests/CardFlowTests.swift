import XCTest
import CoreData
import UIKit
@testable import Pressed

// Flow tests: saving a link, every card type, pressing, rescuing, and Tonight's Stack.
// They run against a throwaway in-memory Core Data store, never the real one.

private let day: TimeInterval = 86_400

/// A fixed "now" so nothing depends on the clock.
private let now = Date(timeIntervalSince1970: 1_750_000_000)

private func web(_ text: String) -> URL { URL(string: text)! }

// MARK: - Shared fixtures

/// One card of every kind, soonest due first, mirroring what the UI tests seed.
private struct SeedCard {
    let title: String
    let url: String
    let kind: CardKind
    let minutes: Int?
    let daysAgo: Int

    static let all: [SeedCard] = [
        SeedCard(title: "7 Short Novels for People Who Say They Don’t Have Time to Read",
                 url: "https://medium.com/hooked-on-books/7-short-novels-for-people-who-say-they-dont-have-time-to-read-7b9aa0749478",
                 kind: .article, minutes: 4, daysAgo: 3),
        SeedCard(title: "Why everyone stopped reading.", url: "https://www.youtube.com/watch?v=A3wJcF0t0bQ",
                 kind: .video, minutes: 12, daysAgo: 2),
        SeedCard(title: "What Should I Read Next?", url: "https://podcasts.apple.com/us/podcast/what-should-i-read-next/id1073499086",
                 kind: .podcast, minutes: 25, daysAgo: 1),
        SeedCard(title: "The Book Riot Podcast on Bluesky", url: "https://bsky.app/profile/bookriotpod.bsky.social",
                 kind: .tweet, minutes: nil, daysAgo: 0)
    ]
}

/// Base class: an in-memory store, a known shelf life, and helpers to add cards.
@MainActor
class StoreTestCase: XCTestCase {
    var persistence: PersistenceController!
    var store: CardStore!
    private var savedShelfLife: Any?

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        store = CardStore(context: persistence.viewContext)
        savedShelfLife = AppGroup.defaults.object(forKey: "shelfLifeDays")
        AppSettings.shelfLifeDays = 7
    }

    override func tearDown() {
        AppGroup.defaults.set(savedShelfLife, forKey: "shelfLifeDays")
        store = nil
        persistence = nil
        super.tearDown()
    }

    /// Adds a pending card and returns it, failing the test if saving did not work.
    @discardableResult
    func addCard(_ text: String = "https://example.com/a",
                 savedAt: Date = now,
                 file: StaticString = #filePath, line: UInt = #line) -> CardRecord {
        guard let record = store.add(url: web(text), savedAt: savedAt) else {
            XCTFail("Saving \(text) returned nil", file: file, line: line)
            fatalError("unreachable")
        }
        return record
    }

    /// Adds the seed cards and gives each its fetched title, kind and minutes, as the metadata fetch would.
    @discardableResult
    func addSeedCards() -> [CardRecord] {
        SeedCard.all.map { seed in
            let record = addCard(seed.url, savedAt: now.addingTimeInterval(-Double(seed.daysAgo) * day))
            store.updateMetadata(
                id: record.id,
                result: MetadataResult(title: seed.title, siteName: nil, imageData: nil,
                                       kind: seed.kind, estMinutes: seed.minutes))
            return store.fetchRecord(id: record.id)!
        }
    }
}

// MARK: - Saving a link

final class SavingALinkTests: StoreTestCase {
    func testSavedLinkIsPendingAndDueAtTheEndOfItsShelfLife() {
        let record = addCard("https://example.com/story")
        XCTAssertEqual(record.status, .pending)
        XCTAssertEqual(record.kind, .article)
        XCTAssertEqual(record.savedAt, now)
        XCTAssertEqual(record.dueAt, ExpiryRules.dueDate(from: now, addingDays: 7))
        XCTAssertNil(record.pressedAt)
        XCTAssertNil(record.rescuedAt)
        XCTAssertEqual(store.fetchPending().map(\.id), [record.id])
        XCTAssertTrue(store.fetchPressed().isEmpty)
    }

    func testUntitledCardShowsItsHostUntilMetadataArrives() {
        let record = addCard("https://www.example.com/story")
        XCTAssertNil(record.title)
        XCTAssertEqual(record.displayTitle, "example.com")
        XCTAssertEqual(record.displaySite, "example.com")
    }

    func testSavingTheSameLinkTwiceKeepsTheFirstCard() {
        let first = addCard("https://example.com/same")
        let second = addCard("https://example.com/same", savedAt: now.addingTimeInterval(day))
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.counts().pending, 1)
    }

    func testOnlyWebLinksAreSaved() {
        for text in ["ftp://example.com/file", "mailto:someone@example.com", "file:///etc/hosts",
                     "javascript:alert(1)", "pressed://stack", "notaurl"] {
            XCTAssertNil(store.add(url: web(text)), "\(text) should not be saved")
        }
        XCTAssertEqual(store.counts().pending, 0)
    }

    func testSchemeIsCaseInsensitive() {
        XCTAssertNotNil(store.add(url: web("HTTPS://example.com/Upper")))
    }

    func testShelfLifeSettingDecidesTheDueDate() {
        for days in [3, 7, 14] {
            AppSettings.shelfLifeDays = days
            let record = addCard("https://example.com/life-\(days)")
            XCTAssertEqual(record.dueAt, ExpiryRules.dueDate(from: now, addingDays: days), "\(days) days")
        }
    }

    func testUnsupportedShelfLifeFallsBackToSeven() {
        AppGroup.defaults.set(5, forKey: "shelfLifeDays")
        XCTAssertEqual(AppSettings.shelfLifeDays, 7)
    }

    func testSavingAgainAfterPressingMakesANewCard() {
        // Only pending cards count as duplicates, so a pressed link can be saved again.
        let first = addCard("https://example.com/again")
        _ = store.press(id: first.id, note: nil, now: now.addingTimeInterval(day))
        let second = addCard("https://example.com/again", savedAt: now.addingTimeInterval(2 * day))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(store.counts().pending, 1)
        XCTAssertEqual(store.counts().pressed, 1)
    }

    func testSavingPostsACardsDidChangeNotification() {
        let posted = XCTNSNotificationExpectation(name: .cardsDidChange)
        addCard()
        wait(for: [posted], timeout: 1)
    }

    // MARK: Share extension hand-off

    func testInboxItemsBecomeCardsAndAreRemoved() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "The app group container is not available in this build.")
        let item = InboxItem(id: UUID(), urlString: "https://example.com/shared", savedAt: now, sealSeed: 4242)
        try Inbox.write(item)

        XCTAssertGreaterThanOrEqual(store.ingestInbox(), 1)

        let record = try XCTUnwrap(store.fetchRecord(id: item.id))
        XCTAssertEqual(record.url.absoluteString, "https://example.com/shared")
        XCTAssertEqual(record.savedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(record.sealSeed, 4242)
        XCTAssertFalse(Inbox.readAll().contains { $0.item.id == item.id }, "The inbox file should be deleted")
        XCTAssertEqual(store.ingestInbox(), 0, "A second pass finds nothing new")
    }

    func testInboxItemWithANonWebLinkIsDroppedWithoutACard() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "The app group container is not available in this build.")
        let item = InboxItem(id: UUID(), urlString: "ftp://example.com/x", savedAt: now, sealSeed: 1)
        try Inbox.write(item)
        store.ingestInbox()
        XCTAssertNil(store.fetchRecord(id: item.id))
        XCTAssertFalse(Inbox.readAll().contains { $0.item.id == item.id })
    }

    func testTheSameLinkSharedTwiceIsOneCard() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "The app group container is not available in this build.")
        let url = "https://example.com/twice"
        let first = InboxItem(id: UUID(), urlString: url, savedAt: now, sealSeed: 1)
        let second = InboxItem(id: UUID(), urlString: url, savedAt: now.addingTimeInterval(60), sealSeed: 2)
        try Inbox.write(first)
        try Inbox.write(second)
        store.ingestInbox()
        let matching = store.fetchPending().filter { $0.url.absoluteString == url }
        XCTAssertEqual(matching.count, 1, "The same link shared twice is one card")
    }
}

// MARK: - Card types

final class CardTypeTests: StoreTestCase {
    func testEachKindIsDetectedFromItsLink() {
        let table: [(String, CardKind)] = [
            ("https://www.nytimes.com/2025/06/01/story.html", .article),
            ("https://www.youtube.com/watch?v=abc", .video),
            ("https://m.youtube.com/watch?v=abc", .video),
            ("https://youtu.be/abc", .video),
            ("https://vimeo.com/123", .video),
            ("https://www.tiktok.com/@a/video/1", .video),
            ("https://podcasts.apple.com/us/podcast/x/id1", .podcast),
            ("https://open.spotify.com/episode/abc", .podcast),
            ("https://open.spotify.com/show/abc", .podcast),
            ("https://overcast.fm/+abc", .podcast),
            ("https://open.spotify.com/track/abc", .article),
            ("https://x.com/a/status/1", .tweet),
            ("https://mobile.twitter.com/a/status/1", .tweet),
            ("https://www.reddit.com/r/swift", .tweet),
            ("https://bsky.app/profile/a", .tweet),
            ("https://www.amazon.com/dp/B000", .article),
            ("https://www.etsy.com/listing/1", .article)
        ]
        for (text, expected) in table {
            XCTAssertEqual(KindDetector.detect(url: web(text)), expected, text)
        }
    }

    func testCardIsStoredWithTheKindTheLinkImplies() {
        for seed in SeedCard.all {
            let record = addCard(seed.url)
            XCTAssertEqual(record.kind, seed.kind, seed.url)
        }
    }

    func testThereIsNoPlaceKindAndMapLinksAreJustArticles() {
        for text in ["https://maps.apple.com/?q=cafe", "https://www.google.com/maps/place/cafe",
                     "https://maps.google.com/?q=cafe", "https://www.yelp.com/biz/cafe",
                     "https://www.tripadvisor.com/Restaurant_Review-x.html"] {
            XCTAssertEqual(KindDetector.detect(url: web(text)), .article, text)
        }
    }

    func testRecipeAndShoppingLinksAreJustArticles() {
        XCTAssertEqual(CardKind.allCases.count, 4)
        for text in ["https://www.bbcgoodfood.com/recipes/easy-focaccia", "https://www.amazon.com/dp/B000",
                     "https://www.etsy.com/listing/1", "https://www.ebay.com/itm/1"] {
            XCTAssertEqual(KindDetector.detect(url: web(text)), .article, text)
        }
    }

    func testRetiredKindsKeepTheirNumbersSoSavedPodcastsAndPostsStayPutOnDisk() {
        XCTAssertEqual(CardKind.article.rawValue, 0)
        XCTAssertEqual(CardKind.video.rawValue, 1)
        XCTAssertEqual(CardKind.podcast.rawValue, 3, "Podcasts were saved as 3; renumbering would turn them into something else")
        XCTAssertEqual(CardKind.tweet.rawValue, 4)
    }

    func testCardsSavedWithARetiredKindLoadAsArticles() throws {
        for retired in [2, 5, 6] as [Int16] {     // recipe, product, place
            let record = addCard("https://example.com/old-\(retired)")
            let request = NSFetchRequest<Card>(entityName: "Card")
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            let row = try XCTUnwrap(persistence.viewContext.fetch(request).first)
            row.kindRaw = retired
            XCTAssertEqual(row.record?.kind, .article, "kind \(retired)")
        }
    }

    func testKindLineShowsTheTypeAndTheTimeWhenKnown() {
        let records = addSeedCards()
        let lines = Dictionary(uniqueKeysWithValues: records.map { ($0.kind, $0.kindLine) })
        XCTAssertEqual(lines[.article], "ARTICLE · 4 MIN")
        XCTAssertEqual(lines[.video], "VIDEO · 12 MIN")
        XCTAssertEqual(lines[.podcast], "PODCAST · 25 MIN")
        XCTAssertEqual(lines[.tweet], "POST")
    }

    func testEveryKindHasALabel() {
        for kind in CardKind.allCases {
            XCTAssertFalse(kind.label.isEmpty)
        }
        XCTAssertEqual(Set(CardKind.allCases.map(\.label)).count, CardKind.allCases.count, "Labels are unique")
    }

    func testMetadataFillsInTitleSiteKindAndMinutes() throws {
        let record = addCard("https://www.youtube.com/watch?v=abc")
        store.updateMetadata(id: record.id, result: MetadataResult(
            title: "  A Great Video \n", siteName: "YouTube", imageData: nil, kind: .video, estMinutes: 9))
        let updated = try XCTUnwrap(store.fetchRecord(id: record.id))
        XCTAssertEqual(updated.title, "A Great Video")
        XCTAssertEqual(updated.displaySite, "YouTube")
        XCTAssertEqual(updated.kind, .video)
        XCTAssertEqual(updated.estMinutes, 9)
        XCTAssertEqual(updated.readTimeText, "9 MIN")
    }

    func testBlankMetadataTitleKeepsTheHostFallback() throws {
        let record = addCard("https://example.com/x")
        store.updateMetadata(id: record.id, result: MetadataResult(
            title: "   ", siteName: nil, imageData: nil, kind: .article, estMinutes: nil))
        let updated = try XCTUnwrap(store.fetchRecord(id: record.id))
        XCTAssertNil(updated.title)
        XCTAssertEqual(updated.displayTitle, "example.com")
    }

    func testMetadataWithoutMinutesDoesNotEraseKnownMinutes() throws {
        let record = addCard("https://example.com/x")
        store.updateMetadata(id: record.id, result: MetadataResult(
            title: "T", siteName: nil, imageData: nil, kind: .article, estMinutes: 6))
        store.updateMetadata(id: record.id, result: MetadataResult(
            title: "T", siteName: nil, imageData: nil, kind: .article, estMinutes: nil))
        XCTAssertEqual(try XCTUnwrap(store.fetchRecord(id: record.id)).estMinutes, 6)
    }

    func testAFetchNeverOverwritesTheUsersOwnTitle() throws {
        let record = addCard("https://example.com/x")
        _ = store.press(id: record.id, note: nil, title: "My own title", now: now.addingTimeInterval(day))
        store.updateMetadata(id: record.id, result: MetadataResult(
            title: "Fetched title", siteName: nil, imageData: nil, kind: .article, estMinutes: nil))
        let updated = try XCTUnwrap(store.fetchRecord(id: record.id))
        XCTAssertEqual(updated.displayTitle, "My own title")
        XCTAssertEqual(updated.fetchedTitle, "Fetched title")
    }

    func testCardsWithoutATitleAreQueuedForLookupUntilTheRetryCapIsReached() {
        let record = addCard("https://example.com/slow")
        XCTAssertEqual(store.cardsNeedingMetadata(now: now).map(\.id), [record.id])

        var clock = now
        for attempt in 1...MetadataRetryPolicy.maxAttempts {
            XCTAssertTrue(store.mayFetchMetadata(id: record.id, ignoringWait: true, now: clock), "attempt \(attempt)")
            store.recordMetadataAttempt(id: record.id, now: clock)
            clock = clock.addingTimeInterval(30 * day)
        }
        XCTAssertFalse(store.mayFetchMetadata(id: record.id, ignoringWait: true, now: clock))
        XCTAssertTrue(store.cardsNeedingMetadata(now: clock).isEmpty)
    }

    func testRetriesWaitBetweenAttempts() {
        let record = addCard("https://example.com/slow")
        store.recordMetadataAttempt(id: record.id, now: now)
        XCTAssertFalse(store.mayFetchMetadata(id: record.id, now: now.addingTimeInterval(60)))
        XCTAssertTrue(store.mayFetchMetadata(id: record.id, now: now.addingTimeInterval(3_700)))
    }

    func testTitledCardsAreNeverLookedUpAgain() {
        let record = addCard("https://example.com/x")
        store.updateMetadata(id: record.id, result: MetadataResult(
            title: "Done", siteName: nil, imageData: nil, kind: .article, estMinutes: nil))
        XCTAssertTrue(store.cardsNeedingMetadata(now: now).isEmpty)
        XCTAssertFalse(store.mayFetchMetadata(id: record.id, ignoringWait: true))
    }

    // Known gaps in KindDetector. XCTExpectFailure keeps the suite green today and goes red, on purpose,
    // the day someone fixes the detector, so the expectation can be deleted.

    func testKnownGapLocalisedSpotifyEpisodeLinksAreNotPodcasts() {
        XCTExpectFailure("Spotify prefixes the path with a locale, e.g. /intl-de/episode/…, which is not matched.") {
            XCTAssertEqual(KindDetector.detect(url: web("https://open.spotify.com/intl-de/episode/abc")), .podcast)
        }
    }
}

// MARK: - Page parsing per card type

final class PageTypeParsingTests: XCTestCase {
    private let base = web("https://example.com/post")

    func testVideoPageGivesTitleImageAndRoundedMinutes() {
        let html = """
        <html><head>
        <meta property="og:title" content="How a Bookbinder Works">
        <meta property="og:image" content="/thumb.jpg">
        <meta property="og:video:duration" content="754">
        </head></html>
        """
        let info = PageParser.parse(html: html, base: base)
        XCTAssertEqual(info.title, "How a Bookbinder Works")
        XCTAssertEqual(info.imageURL, web("https://example.com/thumb.jpg"), "Relative image resolves against the page")
        XCTAssertEqual(info.durationMinutes, 13)
    }

    func testPodcastEpisodeDurationInISOFormat() {
        let html = #"<meta itemprop="duration" content="PT1H2M30S">"#
        XCTAssertEqual(PageParser.parse(html: html, base: base).durationMinutes, 63)
    }

    func testVeryShortMediaStillCountsAsOneMinute() {
        let html = #"<meta property="og:video:duration" content="20">"#
        XCTAssertEqual(PageParser.parse(html: html, base: base).durationMinutes, 1)
    }

    func testBrokenStructuredDataIsIgnored() {
        let html = #"<script type="application/ld+json">{ not json </script><title>Plain</title>"#
        let info = PageParser.parse(html: html, base: base)
        XCTAssertEqual(info.title, "Plain")
    }

    func testArticleReadTimeFollowsWordCount() {
        let words = Array(repeating: "word", count: 2_200).joined(separator: " ")
        XCTAssertEqual(PageParser.parse(html: "<body><p>\(words)</p></body>", base: base).readMinutes, 10)
    }

    func testScriptAndStyleTextDoesNotCountAsReading() {
        let filler = Array(repeating: "noise", count: 3_000).joined(separator: " ")
        let html = "<script>\(filler)</script><style>\(filler)</style><p>short</p>"
        XCTAssertNil(PageParser.parse(html: html, base: base).readMinutes)
    }

    func testEntitiesInTitlesAreDecoded() {
        let html = #"<meta property="og:title" content="Tom &amp; Jerry&#39;s &quot;Show&quot;">"#
        XCTAssertEqual(PageParser.parse(html: html, base: base).title, "Tom & Jerry's \"Show\"")
    }

    func testSingleQuotedAndUppercaseTagsAreRead() {
        let html = "<META PROPERTY='og:title' CONTENT='Loud Page'>"
        XCTAssertEqual(PageParser.parse(html: html, base: base).title, "Loud Page")
    }

    func testPageWithNothingUsefulGivesAnEmptyResult() {
        let info = PageParser.parse(html: "", base: base)
        XCTAssertNil(info.title)
        XCTAssertNil(info.imageURL)
        XCTAssertNil(info.durationMinutes)
        XCTAssertNil(info.readMinutes)
    }
}

// MARK: - Card appearance per type

@MainActor
final class CardContentViewTests: StoreTestCase {
    func testEveryKindRendersItsTitleKindAndDueDate() {
        for record in addSeedCards() {
            let view = CardContentView()
            view.configure(with: record, now: now)
            let spoken = view.spokenSummary
            XCTAssertTrue(spoken.contains(record.displayTitle), "\(record.kind): \(spoken)")
            XCTAssertTrue(spoken.contains(record.kind.label.lowercased()), "\(record.kind): \(spoken)")
            XCTAssertTrue(spoken.contains("due"), "\(record.kind): \(spoken)")
        }
    }

    func testOnlyPendingCardsCurl() {
        let record = addCard(savedAt: now.addingTimeInterval(-6 * day))
        let nearlyDue = CardContentView()
        nearlyDue.configure(with: record, now: record.dueAt.addingTimeInterval(-3_600), pose: false)
        XCTAssertEqual(nearlyDue.paper.level, 3)

        let pressed = store.press(id: record.id, note: nil, now: now)!
        let flat = CardContentView()
        flat.configure(with: pressed, now: now, pose: false)
        XCTAssertEqual(flat.paper.level, 0)
    }
}

// MARK: - Pressing

final class PressingTests: StoreTestCase {
    func testPressingMovesTheCardToTheShelfWithItsNote() throws {
        let record = addCard(savedAt: now.addingTimeInterval(-2 * day))
        let pressed = try XCTUnwrap(store.press(id: record.id, note: "  Loved the ending  ", now: now))

        XCTAssertEqual(pressed.status, .pressed)
        XCTAssertEqual(pressed.pressedAt, now)
        XCTAssertEqual(pressed.note, "Loved the ending")
        XCTAssertTrue(store.fetchPending().isEmpty)
        XCTAssertEqual(store.fetchPressed().map(\.id), [record.id])
        let counts = store.counts()
        XCTAssertEqual([counts.pending, counts.pressed, counts.crumbled], [0, 1, 0])
    }

    func testEmptyOrBlankNoteIsStoredAsNoNote() {
        let blank = addCard("https://example.com/blank")
        let none = addCard("https://example.com/none")
        XCTAssertNil(store.press(id: blank.id, note: " \n ", now: now)?.note)
        XCTAssertNil(store.press(id: none.id, note: nil, now: now)?.note)
    }

    func testTypedTitleBecomesTheDisplayTitleAndBlankLeavesTheFetchedOne() {
        let typed = addCard("https://example.com/typed")
        let blank = addCard("https://example.com/blank")
        store.updateMetadata(id: blank.id, result: MetadataResult(
            title: "Fetched", siteName: nil, imageData: nil, kind: .article, estMinutes: nil))

        XCTAssertEqual(store.press(id: typed.id, note: nil, title: "  My title ", now: now)?.displayTitle, "My title")
        XCTAssertEqual(store.press(id: blank.id, note: nil, title: "   ", now: now)?.displayTitle, "Fetched")
    }

    func testPressingTheDaySavedIsFresh() {
        let record = addCard(savedAt: now.addingTimeInterval(-3_600))
        XCTAssertEqual(store.press(id: record.id, note: nil, now: now)?.finish, .fresh)
    }

    func testPressingInTheLastDayIsACloseCall() {
        let record = addCard(savedAt: now.addingTimeInterval(-5 * day))
        XCTAssertEqual(store.press(id: record.id, note: nil, now: record.dueAt.addingTimeInterval(-3_600))?.finish,
                       .closeCall)
    }

    func testLongReadsEarnTheirFinish() {
        let record = addCard(savedAt: now.addingTimeInterval(-2 * day))
        store.updateMetadata(id: record.id, result: MetadataResult(
            title: "Long", siteName: nil, imageData: nil, kind: .article, estMinutes: 25))
        XCTAssertEqual(store.press(id: record.id, note: nil, now: now)?.finish, .longRead)
    }

    func testAnOrdinaryPressHasNoSpecialFinish() {
        let record = addCard(savedAt: now.addingTimeInterval(-2 * day))
        XCTAssertEqual(store.press(id: record.id, note: nil, now: now)?.finish, CardFinish.none)
    }

    func testAPressedCardCannotBePressedAgain() throws {
        let record = addCard(savedAt: now.addingTimeInterval(-2 * day))
        _ = store.press(id: record.id, note: "first", now: now)
        XCTAssertNil(store.press(id: record.id, note: "second", now: now.addingTimeInterval(60)))
        let stored = try XCTUnwrap(store.fetchRecord(id: record.id))
        XCTAssertEqual(stored.note, "first")
        XCTAssertEqual(stored.pressedAt, now)
    }

    func testACrumbledCardCannotBePressed() throws {
        let record = addCard(savedAt: now.addingTimeInterval(-2 * day))
        store.crumble(id: record.id, now: now)
        XCTAssertNil(store.press(id: record.id, note: nil, now: now))
        XCTAssertEqual(try XCTUnwrap(store.fetchRecord(id: record.id)).status, .crumbled)
    }

    func testPressingAMissingCardIsHarmless() {
        XCTAssertNil(store.press(id: UUID(), note: nil, now: now))
    }

    func testShelfListsNewestPressFirstAndNumbersFollowPressOrder() {
        let cards = (1...3).map { addCard("https://example.com/\($0)", savedAt: now.addingTimeInterval(-3 * day)) }
        let pressed = cards.enumerated().compactMap { index, card in
            store.press(id: card.id, note: nil, now: now.addingTimeInterval(Double(index) * 60))
        }
        XCTAssertEqual(store.fetchPressed().map(\.id), pressed.reversed().map(\.id))
        XCTAssertEqual(pressed.map { store.pressedNumber(for: $0) }, [1, 2, 3])
    }

    func testPressingPostsACardsDidChangeNotification() {
        let record = addCard(savedAt: now.addingTimeInterval(-2 * day))
        let posted = XCTNSNotificationExpectation(name: .cardsDidChange)
        _ = store.press(id: record.id, note: nil, now: now)
        wait(for: [posted], timeout: 1)
    }

    func testDeletingRemovesACardForGood() {
        let record = addCard()
        store.delete(id: record.id)
        XCTAssertNil(store.fetchRecord(id: record.id))
        XCTAssertEqual(store.counts().pending, 0)
    }
}

// MARK: - Crumbling and rescue

final class CrumbleAndRescueTests: StoreTestCase {
    func testSweepCrumblesOnlyCardsPastTheirDueDate() throws {
        let old = addCard("https://example.com/old", savedAt: now.addingTimeInterval(-10 * day))
        let fresh = addCard("https://example.com/fresh", savedAt: now)

        XCTAssertEqual(store.expiredPending(now: now).map(\.id), [old.id])
        XCTAssertEqual(store.sweepExpired(now: now).map(\.id), [old.id])

        let swept = try XCTUnwrap(store.fetchRecord(id: old.id))
        XCTAssertEqual(swept.status, .crumbled)
        XCTAssertEqual(swept.crumbledAt, now)
        XCTAssertEqual(try XCTUnwrap(store.fetchRecord(id: fresh.id)).status, .pending)
        XCTAssertTrue(store.sweepExpired(now: now).isEmpty, "Nothing is swept twice")
    }

    func testLettingGoCrumblesAPendingCard() throws {
        let record = addCard()
        store.crumble(id: record.id, now: now)
        XCTAssertEqual(try XCTUnwrap(store.fetchRecord(id: record.id)).status, .crumbled)
        XCTAssertEqual(store.counts().crumbled, 1)
    }

    func testCrumblingAPressedCardDoesNothing() throws {
        let record = addCard(savedAt: now.addingTimeInterval(-2 * day))
        _ = store.press(id: record.id, note: nil, now: now)
        store.crumble(id: record.id, now: now)
        XCTAssertEqual(try XCTUnwrap(store.fetchRecord(id: record.id)).status, .pressed)
    }

    func testRescueGivesAnExpiredCardTheRestOfTodayOnce() throws {
        let record = addCard(savedAt: now.addingTimeInterval(-10 * day))
        let rescued = try XCTUnwrap(store.rescueIfExpired(id: record.id, now: now))
        XCTAssertEqual(rescued.dueAt, ExpiryRules.dueDate(from: now, addingDays: 0))
        XCTAssertEqual(rescued.rescuedAt, now)
        XCTAssertTrue(store.expiredPending(now: now).isEmpty)
        XCTAssertNil(store.rescueIfExpired(id: record.id, now: now.addingTimeInterval(2 * day)), "Only once per card")
    }

    func testRescueIgnoresCardsThatAreStillAlive() {
        let record = addCard(savedAt: now)
        XCTAssertNil(store.rescueIfExpired(id: record.id, now: now))
    }

    func testRescueIgnoresCardsThatAreAlreadyCrumbled() {
        let record = addCard(savedAt: now.addingTimeInterval(-10 * day))
        store.crumble(id: record.id, now: now)
        XCTAssertNil(store.rescueIfExpired(id: record.id, now: now))
    }

    func testARescuedCardCanStillBePressedAndKeepsTheRescuedFinish() throws {
        let record = addCard(savedAt: now.addingTimeInterval(-10 * day))
        _ = store.rescueIfExpired(id: record.id, now: now)
        let pressed = try XCTUnwrap(store.press(id: record.id, note: nil, now: now.addingTimeInterval(3_600)))
        XCTAssertEqual(pressed.finish, .rescued)
        XCTAssertEqual(pressed.status, .pressed)
    }

    func testDebugAgeMovesCardsTowardsTheirDueDate() throws {
        let record = addCard(savedAt: Date())
        store.debugAge(days: 8)
        XCTAssertEqual(store.expiredPending().map(\.id), [record.id])
    }
}

// MARK: - Tonight's Stack

final class TonightsStackTests: StoreTestCase {
    private func titles(_ result: StackResult) -> [String] { result.cards.map(\.displayTitle) }

    func testWithNoTimeLimitTheThreeSoonestDueCardsAreChosen() {
        addSeedCards()
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: nil)
        XCTAssertEqual(titles(result), ["7 Short Novels for People Who Say They Don’t Have Time to Read", "Why everyone stopped reading.", "What Should I Read Next?"])
        XCTAssertEqual(result.totalMinutes, 4 + 12 + 25)
    }

    func testFiveMinutesFitsOnlyTheShortArticle() {
        addSeedCards()
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: 5)
        XCTAssertEqual(titles(result), ["7 Short Novels for People Who Say They Don’t Have Time to Read"])
        XCTAssertEqual(result.totalMinutes, 4)
    }

    func testFifteenMinutesSkipsWhatDoesNotFitAndTakesTheNextThatDoes() {
        addSeedCards()
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: 15)
        // article (4) + video (12) is 16, so the video is skipped; the post has no time and counts as the default 10.
        XCTAssertEqual(titles(result), ["7 Short Novels for People Who Say They Don’t Have Time to Read", "The Book Riot Podcast on Bluesky"])
        XCTAssertEqual(result.totalMinutes, 14)
    }

    func testThirtyMinutes() {
        addSeedCards()
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: 30)
        XCTAssertEqual(titles(result), ["7 Short Novels for People Who Say They Don’t Have Time to Read", "Why everyone stopped reading.", "The Book Riot Podcast on Bluesky"])
        XCTAssertEqual(result.totalMinutes, 26)
    }

    func testCardsWithoutATimeCountAsTenMinutes() {
        let record = addCard()
        XCTAssertEqual(StackPicker.minutes(for: record), StackPicker.defaultMinutes)
        XCTAssertEqual(StackPicker.defaultMinutes, 10)
    }

    func testWhenNothingFitsTheMostUrgentCardIsOfferedAnyway() {
        let long = addCard("https://example.com/long")
        store.updateMetadata(id: long.id, result: MetadataResult(
            title: "Long", siteName: nil, imageData: nil, kind: .podcast, estMinutes: 25))
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: 5)
        XCTAssertEqual(result.cards.map(\.id), [long.id])
        XCTAssertEqual(result.totalMinutes, 25)
    }

    func testPressedAndCrumbledCardsLeaveTheStack() {
        let records = addSeedCards()
        _ = store.press(id: records[0].id, note: nil, now: now)
        store.crumble(id: records[1].id, now: now)
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: nil)
        XCTAssertEqual(titles(result), ["What Should I Read Next?", "The Book Riot Podcast on Bluesky"])
    }

    func testEmptyPileGivesAnEmptyStack() {
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: nil)
        XCTAssertTrue(result.cards.isEmpty)
        XCTAssertEqual(result.totalMinutes, 0)
    }

    func testStackNeverHoldsMoreThanThreeCards() {
        addSeedCards()
        for budget in [nil, 5, 15, 30, 60, 600] as [Int?] {
            XCTAssertLessThanOrEqual(StackPicker.pick(from: store.fetchPending(), budgetMinutes: budget).cards.count, 3)
        }
    }

    func testStackNeverRunsOverABudgetUnlessItIsTheSingleFallbackCard() {
        addSeedCards()
        for budget in [5, 15, 30, 60] {
            let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: budget)
            if result.cards.count > 1 {
                XCTAssertLessThanOrEqual(result.totalMinutes, budget, "budget \(budget)")
            }
        }
    }

    func testAThirdCardOfTheSameKindIsSwappedForAnotherKindWhenOneIsAvailable() {
        for index in 1...4 {
            let record = addCard("https://example.com/a\(index)", savedAt: now.addingTimeInterval(-Double(10 - index) * day))
            store.updateMetadata(id: record.id, result: MetadataResult(
                title: "Article \(index)", siteName: nil, imageData: nil, kind: .article, estMinutes: 5))
        }
        let video = addCard("https://www.youtube.com/watch?v=v", savedAt: now.addingTimeInterval(-1 * day))
        store.updateMetadata(id: video.id, result: MetadataResult(
            title: "The Video", siteName: nil, imageData: nil, kind: .video, estMinutes: 5))

        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: nil)
        XCTAssertEqual(titles(result), ["Article 1", "Article 2", "The Video"])
    }
}

// MARK: - Hold to press

@MainActor
final class HoldToPressControlTests: XCTestCase {
    private func makeControl() -> (HoldToPressControl, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let control = HoldToPressControl()
        control.frame = CGRect(x: 20, y: 100, width: 350, height: 58)
        window.addSubview(control)
        window.isHidden = false
        control.layoutIfNeeded()
        return (control, window)
    }

    func testVoiceOverUsersCanPressWithoutHolding() {
        let (control, window) = makeControl()
        var presses = 0
        control.addAction(UIAction { _ in presses += 1 }, for: .primaryActionTriggered)

        XCTAssertTrue(control.isAccessibilityElement)
        XCTAssertTrue(control.accessibilityTraits.contains(.button))
        XCTAssertEqual(control.accessibilityLabel, "Press")
        XCTAssertTrue(control.accessibilityActivate())
        XCTAssertTrue(control.accessibilityActivate(), "A second activation is absorbed")

        XCTAssertEqual(presses, 1)
        XCTAssertTrue(control.isComplete)
        _ = window
    }

    func testHoldingForTheFullDurationPresses() {
        let (control, window) = makeControl()
        let pressed = expectation(description: "press completes")
        control.addAction(UIAction { _ in pressed.fulfill() }, for: .primaryActionTriggered)

        control.debugHold()

        wait(for: [pressed], timeout: 3)
        XCTAssertTrue(control.isComplete)
        _ = window
    }

    func testResetLetsTheControlBeUsedAgain() {
        let (control, window) = makeControl()
        var presses = 0
        control.addAction(UIAction { _ in presses += 1 }, for: .primaryActionTriggered)

        _ = control.accessibilityActivate()
        control.reset()
        XCTAssertFalse(control.isComplete)
        _ = control.accessibilityActivate()

        XCTAssertEqual(presses, 2)
        _ = window
    }
}
