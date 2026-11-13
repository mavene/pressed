#if DEBUG
import UIKit

/// Invented content for public marketing captures (App Store screenshots, the website, videos), so nothing real
/// is shown: no third-party titles, thumbnails, podcast artwork or logos.
///
/// Every link uses a `.example` host, a name reserved by RFC 2606 that can never belong to a real site, and the
/// artwork is drawn here. Nothing is fetched from the network.
///
/// Launch with `-promoContent` to switch the screenshot scenes and the `-uitest-seed` cards over to this set.
/// Without the flag everything keeps using the real reading links in `DebugSamples`.
enum PromoSamples {
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-promoContent") }

    static let article = DebugSamples.Link(
        title: "Seven Short Novels for People Who Never Have the Time", site: "The Lantern Review",
        url: "https://lantern-review.example/essays/short-novels", kind: .article, minutes: 4)

    static let video = DebugSamples.Link(
        title: "Why We Stopped Finishing Books", site: "Slowframe",
        url: "https://slowframe.example/watch/why-we-stopped-finishing-books", kind: .video, minutes: 12)

    static let podcast = DebugSamples.Link(
        title: "Margin Notes", site: "Paperback Radio",
        url: "https://paperback-radio.example/shows/margin-notes", kind: .podcast, minutes: 25)

    static let post = DebugSamples.Link(
        title: "Dog-Ear Daily on Murmur", site: "Murmur",
        url: "https://murmur.example/dogear", kind: .tweet, minutes: nil)

    /// A reference-style article, for the promo scenes that used a Wikipedia page.
    static let reference = DebugSamples.Link(
        title: "Paper folding", site: "Open Almanac",
        url: "https://open-almanac.example/wiki/paper-folding", kind: .article, minutes: 9)

    static let all: [DebugSamples.Link] = [article, video, podcast, post]

    /// A page on the invented reference site, for the Shelf and press scenes.
    static func almanac(_ slug: String) -> String { "https://open-almanac.example/wiki/\(slug)" }

    // MARK: Metadata

    /// What a real fetch would have filled in, but invented: title, site, kind and a drawn thumbnail.
    static func metadata(_ link: DebugSamples.Link, title: String? = nil, site: String? = nil,
                         minutes: Int? = nil) -> MetadataResult {
        MetadataResult(title: title ?? link.title, siteName: site ?? link.site,
                       imageData: art(for: link.url), kind: link.kind, estMinutes: minutes ?? link.minutes)
    }

    // MARK: Drawn artwork

    private static let palette: [(UIColor, UIColor, String)] = [
        (UIColor(red: 0.93, green: 0.55, blue: 0.30, alpha: 1), UIColor(red: 0.80, green: 0.32, blue: 0.22, alpha: 1), "book.closed.fill"),
        (UIColor(red: 0.30, green: 0.52, blue: 0.62, alpha: 1), UIColor(red: 0.14, green: 0.28, blue: 0.40, alpha: 1), "text.quote"),
        (UIColor(red: 0.55, green: 0.60, blue: 0.38, alpha: 1), UIColor(red: 0.28, green: 0.38, blue: 0.24, alpha: 1), "leaf.fill"),
        (UIColor(red: 0.62, green: 0.42, blue: 0.58, alpha: 1), UIColor(red: 0.36, green: 0.22, blue: 0.40, alpha: 1), "books.vertical.fill"),
        (UIColor(red: 0.88, green: 0.50, blue: 0.52, alpha: 1), UIColor(red: 0.62, green: 0.24, blue: 0.34, alpha: 1), "quote.bubble.fill")
    ]

    /// A square cover in a warm or cool gradient with one glyph. The same link always gets the same cover.
    static func art(for url: String) -> Data? {
        // A stable hash (String.hashValue changes every launch), so a link keeps its cover between captures.
        let stable = url.utf8.reduce(UInt32(5381)) { ($0 &* 33) &+ UInt32($1) }
        // The five main links each get their own colour, so neighbours in the pile never match.
        let fixed: [String: Int] = [article.url: 0, reference.url: 1, video.url: 2, podcast.url: 3, post.url: 4]
        let pick = palette[fixed[url] ?? Int(stable) % palette.count]
        let size = CGSize(width: 320, height: 320)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let colors = [pick.0.cgColor, pick.1.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            let config = UIImage.SymbolConfiguration(pointSize: 140, weight: .regular)
            if let glyph = UIImage(systemName: pick.2, withConfiguration: config)?
                .withTintColor(UIColor.white.withAlphaComponent(0.85), renderingMode: .alwaysOriginal) {
                let rect = CGRect(x: (size.width - glyph.size.width) / 2, y: (size.height - glyph.size.height) / 2,
                                  width: glyph.size.width, height: glyph.size.height)
                glyph.draw(in: rect)
            }
        }
        return image.jpegData(compressionQuality: 0.85)
    }
}

/// The set the scenes and seeds actually use: invented under `-promoContent`, the real reading links otherwise.
enum ActiveSamples {
    private static var promo: Bool { PromoSamples.isActive }
    static var article: DebugSamples.Link { promo ? PromoSamples.article : DebugSamples.article }
    static var video: DebugSamples.Link { promo ? PromoSamples.video : DebugSamples.video }
    static var podcast: DebugSamples.Link { promo ? PromoSamples.podcast : DebugSamples.podcast }
    static var post: DebugSamples.Link { promo ? PromoSamples.post : DebugSamples.post }
    static var all: [DebugSamples.Link] { promo ? PromoSamples.all : DebugSamples.all }

    /// A reference-style page: Wikipedia normally, the invented almanac for promo captures.
    static func reference(_ slug: String) -> String {
        promo ? PromoSamples.almanac(slug.lowercased().replacingOccurrences(of: "_", with: "-"))
              : "https://en.wikipedia.org/wiki/\(slug)"
    }
}
#endif
