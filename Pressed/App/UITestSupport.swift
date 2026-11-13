#if DEBUG
import Foundation

/// Launch-argument hooks so UI tests start from a known state without touching real data. Debug builds only.
///
///     -uitest              in-memory store, onboarding skipped, no permission prompts, 7-day shelf life
///     -uitest-onboarding   with -uitest: show the first-launch pages
///     -uitest-seed         with -uitest: one pending card of every kind (see `seedCards`)
///     -uitest-share <url>  with -uitest: queue the link exactly as the share extension would
///     -promoContent        with the seeds and screenshot scenes: invented links and artwork, nothing real
enum UITestSupport {
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }

    /// One card per kind, oldest first, so "most curled first" order is the order listed here.
    /// `UITestSeed` in the UI test bundle mirrors this list.
    /// With `-promoContent` these are the invented marketing links instead of the real ones.
    static var seedCards: [(sample: DebugSamples.Link, daysAgo: Int)] {
        [(ActiveSamples.article, 3), (ActiveSamples.video, 2), (ActiveSamples.podcast, 1), (ActiveSamples.post, 0)]
    }

    @MainActor
    static func prepare() {
        guard isActive else { return }
        let arguments = ProcessInfo.processInfo.arguments

        AppSettings.shelfLifeDays = 7
        AppSettings.nudgeEnabled = false
        AppSettings.hasAskedForNotifications = true
        AppSettings.hasOnboarded = !arguments.contains("-uitest-onboarding")

        // Anything an earlier run left in the shared inbox would turn into a surprise card.
        for entry in Inbox.readAll() { try? FileManager.default.removeItem(at: entry.file) }

        if arguments.contains("-uitest-seed") { seed() }
        if let flag = arguments.firstIndex(of: "-uitest-share"), arguments.indices.contains(flag + 1) {
            let item = InboxItem(id: UUID(), urlString: arguments[flag + 1], savedAt: Date(), sealSeed: 1234)
            try? Inbox.write(item)
        }
    }

    @MainActor
    private static func seed(now: Date = Date()) {
        for card in seedCards {
            let sample = card.sample
            guard let url = URL(string: sample.url),
                  let record = CardStore.shared.add(
                    url: url, savedAt: now.addingTimeInterval(-Double(card.daysAgo) * 86_400)) else { continue }
            CardStore.shared.updateMetadata(
                id: record.id,
                result: MetadataResult(title: sample.title, siteName: sample.site,
                                       imageData: PromoSamples.isActive ? PromoSamples.art(for: sample.url) : nil,
                                       kind: sample.kind, estMinutes: sample.minutes))
        }
    }
}
#endif
