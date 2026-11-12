import Foundation

// Plain value types (Foundation only).

enum CardKind: Int16, CaseIterable {
    // The raw values are what is stored on disk, so they are never renumbered or reused. 2 (recipe),
    // 5 (product) and 6 (place) were retired; rows saved with them still load, as articles (see `Card.record`).
    case article = 0, video = 1, podcast = 3, tweet = 4

    var label: String {
        switch self {
        case .article: return "ARTICLE"
        case .video: return "VIDEO"
        case .podcast: return "PODCAST"
        case .tweet: return "POST"
        }
    }
}

enum CardStatus: Int16 {
    case pending = 0, pressed, crumbled
}

enum CardFinish: Int16 {
    case none = 0, fresh, closeCall, longRead, rescued
}

struct CardRecord: Hashable, Identifiable {
    var id: UUID
    var url: URL
    var title: String?
    var siteName: String?
    var imageData: Data?
    var kind: CardKind
    var estMinutes: Int?
    var savedAt: Date
    var dueAt: Date
    var status: CardStatus
    var pressedAt: Date?
    var crumbledAt: Date?
    var rescuedAt: Date?
    var note: String?
    var finish: CardFinish
    var sealSeed: Int32
    /// What the user typed on the press screen. Beats the fetched title and is never overwritten by a fetch.
    var customTitle: String? = nil
}

extension CardRecord {
    /// Host without a leading "www.".
    var host: String {
        let raw = url.host ?? url.absoluteString
        return raw.replacingOccurrences(of: "www.", with: "", options: .anchored)
    }

    /// The user's own title, else the fetched one, else the host.
    var displayTitle: String {
        let custom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? fetchedTitle : custom
    }

    /// The fetched title, else the host. Ignores any custom title.
    var fetchedTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? host : trimmed
    }

    var displaySite: String {
        let trimmed = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? host : trimmed
    }

    var readTimeText: String? {
        guard let minutes = estMinutes, minutes > 0 else { return nil }
        return "\(minutes) MIN"
    }

    /// "ARTICLE · 7 MIN"
    var kindLine: String {
        [kind.label, readTimeText].compactMap { $0 }.joined(separator: " · ")
    }
}
