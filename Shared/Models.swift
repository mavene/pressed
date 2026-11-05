import Foundation

// Plain value types (Foundation only).

enum CardKind: Int16, CaseIterable {
    case article = 0, video, recipe, podcast, tweet, product, place

    var label: String {
        switch self {
        case .article: return "ARTICLE"
        case .video: return "VIDEO"
        case .recipe: return "RECIPE"
        case .podcast: return "PODCAST"
        case .tweet: return "POST"
        case .product: return "PRODUCT"
        case .place: return "PLACE"
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
}

extension CardRecord {
    /// Host without a leading "www.".
    var host: String {
        let raw = url.host ?? url.absoluteString
        return raw.replacingOccurrences(of: "www.", with: "", options: .anchored)
    }

    var displayTitle: String {
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
