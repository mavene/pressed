import Foundation

// MARK: - Curl

enum CurlRules {
    /// Curl level from the share of shelf life still remaining.
    /// Curl level from remaining shelf life (0 flat to 3 rolled); nil when expired.
    static func level(savedAt: Date, dueAt: Date, now: Date) -> Int? {
        let total = dueAt.timeIntervalSince(savedAt)
        let remaining = dueAt.timeIntervalSince(now)
        guard total > 0, remaining > 0 else { return nil }
        let share = remaining / total
        if share > 0.7 { return 0 }
        if share > 0.5 { return 1 }
        if share > 0.3 { return 2 }
        return 3
    }

    static func isExpired(dueAt: Date, now: Date) -> Bool {
        dueAt <= now
    }
}

// MARK: - Expiry

enum ExpiryRules {
    /// A card lasts through the whole of its last day, so it expires at 23:59:59 on that day, not at the
    /// time of day it was saved.
    static func dueDate(from start: Date, addingDays days: Int, calendar: Calendar = .current) -> Date {
        let lastDay = calendar.date(byAdding: .day, value: days, to: start) ?? start
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay)) ?? lastDay
        return nextMidnight.addingTimeInterval(-1)
    }
}

// MARK: - Metadata retries

/// How often a card with no title may be looked up again. A card gets at most `maxAttempts` tries in total,
/// with longer waits in between, so a site that never answers is not hammered on every launch.
enum MetadataRetryPolicy {
    static let maxAttempts = 4
    /// Wait before the 2nd, 3rd and 4th attempt.
    static let waits: [TimeInterval] = [3_600, 6 * 3_600, 24 * 3_600]

    static func shouldAttempt(attempts: Int, lastAttemptAt: Date?, now: Date, ignoringWait: Bool = false) -> Bool {
        guard attempts < maxAttempts else { return false }
        guard attempts > 0, let last = lastAttemptAt, !ignoringWait else { return true }
        return now.timeIntervalSince(last) >= waits[min(attempts - 1, waits.count - 1)]
    }
}

// MARK: - Due label

enum DueLabel {
    /// "DUE TODAY", "DUE TOMORROW", "DUE SAT", "DUE 12 NOV"
    static func text(dueAt: Date, now: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueAt)
        let days = calendar.dateComponents([.day], from: start, to: dueDay).day ?? 0
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        switch days {
        case ..<1:
            return "DUE TODAY"
        case 1:
            return "DUE TOMORROW"
        case 2...6:
            formatter.dateFormat = "EEE"
            return "DUE " + formatter.string(from: dueAt).uppercased()
        default:
            formatter.dateFormat = "d MMM"
            return "DUE " + formatter.string(from: dueAt).uppercased()
        }
    }
}

// MARK: - Finish

enum FinishRules {
    static let day: TimeInterval = 24 * 3600

    static func finish(savedAt: Date,
                       pressedAt: Date,
                       dueAt: Date,
                       estMinutes: Int?,
                       rescued: Bool) -> CardFinish {
        if pressedAt.timeIntervalSince(savedAt) < day { return .fresh }
        if rescued { return .rescued }
        if dueAt.timeIntervalSince(pressedAt) <= day { return .closeCall }
        if (estMinutes ?? 0) >= 20 { return .longRead }
        return .none
    }

    /// Short name and one-line description for the bookmark detail screen.
    static func caption(for finish: CardFinish) -> (name: String, detail: String) {
        switch finish {
        case .none: return ("PRESSED", "Pressed flat and kept")
        case .fresh: return ("FRESH", "Read the day you saved it")
        case .closeCall: return ("CLOSE CALL", "Pressed just before it crumbled")
        case .longRead: return ("LONG READ", "A big one, finished")
        case .rescued: return ("RESCUED", "Saved from crumbling")
        }
    }
}

// MARK: - Kind detection

enum KindDetector {
    static func detect(url: URL, isRecipePage: Bool = false) -> CardKind {
        var host = (url.host ?? "").lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let path = url.path.lowercased()

        if matches(host, ["youtube.com", "youtu.be", "vimeo.com", "tiktok.com", "twitch.tv"]) {
            return .video
        }
        if host == "open.spotify.com" {
            return (path.hasPrefix("/episode") || path.hasPrefix("/show")) ? .podcast : .article
        }
        if matches(host, ["podcasts.apple.com", "overcast.fm", "pocketcasts.com"]) {
            return .podcast
        }
        if matches(host, ["x.com", "twitter.com", "threads.net", "threads.com", "bsky.app",
                          "instagram.com", "reddit.com", "mastodon.social"]) {
            return .tweet
        }
        if isAmazon(host) || matches(host, ["etsy.com", "ebay.com"]) {
            return .product
        }
        if matches(host, ["maps.apple.com", "yelp.com", "tripadvisor.com"])
            || (host == "google.com" && path.hasPrefix("/maps")) {
            return .place
        }
        if isRecipePage { return .recipe }
        return .article
    }

    private static func matches(_ host: String, _ domains: [String]) -> Bool {
        domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func isAmazon(_ host: String) -> Bool {
        host.hasPrefix("amazon.") || host.contains(".amazon.")
    }
}
