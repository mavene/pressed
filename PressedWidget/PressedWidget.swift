import SwiftUI
import WidgetKit
import CoreData

// MARK: - Data

/// What the widget needs from one pending card.
struct WidgetCard: Identifiable {
    let id: UUID
    let title: String
    let site: String
    let kindLine: String
    let savedAt: Date
    let dueAt: Date
}

struct PressedEntry: TimelineEntry {
    let date: Date
    let card: WidgetCard?
    let pendingCount: Int
}

/// Reads pending cards straight from the shared Core Data store.
enum WidgetData {
    static func pending() -> [WidgetCard] {
        let context = PersistenceController.shared.container.newBackgroundContext()
        var result: [WidgetCard] = []
        var knownURLs = Set<String>()
        context.performAndWait {
            let request = NSFetchRequest<Card>(entityName: "Card")
            request.predicate = NSPredicate(format: "statusRaw == %@", NSNumber(value: CardStatus.pending.rawValue))
            request.sortDescriptors = [NSSortDescriptor(key: "dueAt", ascending: true)]
            let cards = (try? context.fetch(request)) ?? []
            for card in cards {
                if let known = card.urlString { knownURLs.insert(known) }
                guard let id = card.id,
                      let urlString = card.urlString,
                      let url = URL(string: urlString),
                      let savedAt = card.savedAt,
                      let dueAt = card.dueAt else { continue }
                let kind = CardKind(rawValue: card.kindRaw) ?? .article
                let record = CardRecord(
                    id: id, url: url, title: card.title, siteName: card.siteName, imageData: nil,
                    kind: kind, estMinutes: card.estMinutes > 0 ? Int(card.estMinutes) : nil,
                    savedAt: savedAt, dueAt: dueAt, status: .pending, pressedAt: nil, crumbledAt: nil,
                    rescuedAt: nil, note: nil, finish: .none, sealSeed: card.sealSeed)
                result.append(WidgetCard(
                    id: id, title: record.displayTitle, site: record.displaySite,
                    kindLine: record.kindLine, savedAt: savedAt, dueAt: dueAt))
            }
        }
        // The app only imports shared links when it opens, so show the ones still waiting in the Inbox too.
        result += unimportedLinks(excluding: knownURLs)
        return result.sorted { $0.dueAt < $1.dueAt }
    }

    /// Links saved from the Share sheet that the app has not turned into cards yet. They get the same
    /// deadline the app will give them, and the host as a title until the app fetches the real one.
    private static func unimportedLinks(excluding known: Set<String>) -> [WidgetCard] {
        let stored = AppGroup.defaults.integer(forKey: "shelfLifeDays")
        let days = [3, 7, 14].contains(stored) ? stored : 7
        var seen = known
        var cards: [WidgetCard] = []
        for entry in Inbox.readAll() {
            guard let url = URL(string: entry.item.urlString),
                  seen.insert(url.absoluteString).inserted else { continue }
            let dueAt = ExpiryRules.dueDate(from: entry.item.savedAt, addingDays: days)
            let record = CardRecord(
                id: entry.item.id, url: url, title: nil, siteName: nil, imageData: nil,
                kind: KindDetector.detect(url: url), estMinutes: nil,
                savedAt: entry.item.savedAt, dueAt: dueAt, status: .pending, pressedAt: nil, crumbledAt: nil,
                rescuedAt: nil, note: nil, finish: .none, sealSeed: entry.item.sealSeed)
            cards.append(WidgetCard(
                id: entry.item.id, title: record.displayTitle, site: record.displaySite,
                kindLine: record.kindLine, savedAt: entry.item.savedAt, dueAt: dueAt))
        }
        return cards
    }
}

// MARK: - Timeline

struct PressedProvider: TimelineProvider {
    /// How many of the most urgent cards take turns on screen.
    private let rotation = 5
    private let step: TimeInterval = 30 * 60
    private let horizon: TimeInterval = 24 * 3600

    func placeholder(in context: Context) -> PressedEntry {
        PressedEntry(date: Date(), card: Self.sample, pendingCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (PressedEntry) -> Void) {
        let cards = WidgetData.pending()
        if let first = cards.first {
            completion(PressedEntry(date: Date(), card: first, pendingCount: cards.count))
        } else if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(PressedEntry(date: Date(), card: nil, pendingCount: 0))
        }
    }

    /// Builds a day of entries up front. Each one is drawn at its own time, so the curl and stamp
    /// keep ageing without the app running and without spending refresh budget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PressedEntry>) -> Void) {
        let cards = WidgetData.pending()
        let now = Date()
        guard !cards.isEmpty else {
            completion(Timeline(entries: [PressedEntry(date: now, card: nil, pendingCount: 0)],
                                policy: .after(now.addingTimeInterval(horizon))))
            return
        }
        let shown = Array(cards.prefix(rotation))
        var entries: [PressedEntry] = []
        var date = now
        var index = 0
        while date < now.addingTimeInterval(horizon) {
            entries.append(PressedEntry(date: date, card: shown[index % shown.count], pendingCount: cards.count))
            index += 1
            date = date.addingTimeInterval(step)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(horizon))))
    }

    private static var sample: WidgetCard {
        WidgetCard(id: UUID(), title: "The Ultimate Guide to Guides", site: "example.com",
                   kindLine: "ARTICLE · 7 MIN",
                   savedAt: Date().addingTimeInterval(-5 * 86_400), dueAt: Date().addingTimeInterval(2 * 86_400))
    }
}

// MARK: - Look

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static let paper = Color(hex: 0xFBF8F1)
    static let ink = Color(hex: 0x231E18)
    static let inkQuiet = Color(hex: 0x62574A)
    static let stampRed = Color(hex: 0x8E2A20)
    static let outline = Color(hex: 0xCDBFA9)
    static let waxFill = Color(hex: 0x9E2F24)
    static let waxRing = Color(hex: 0x6E1E16)
    static let waxLetter = Color(hex: 0xF1D3C8)
}

private struct Fold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StampView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(Color.stampRed)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.stampRed, lineWidth: 1.5))
            .rotationEffect(.degrees(-4))
    }
}

/// The scalloped wax seal body, same geometry as the app's `WaxSealView`.
private struct SealBody: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addEllipse(in: CGRect(x: c.x - r * 0.75, y: c.y - r * 0.75, width: r * 1.5, height: r * 1.5))
        for k in 0..<12 {
            let angle = CGFloat(k) * (.pi * 2 / 12)
            let center = CGPoint(x: c.x + cos(angle) * r * 0.78, y: c.y + sin(angle) * r * 0.78)
            path.addEllipse(in: CGRect(x: center.x - r * 0.17, y: center.y - r * 0.17,
                                       width: r * 0.34, height: r * 0.34))
        }
        return path
    }
}

/// The plain red seal (the app's `.none` finish) at a fixed angle, so it always looks the same.
private struct WaxSealMark: View {
    var size: CGFloat = 48

    var body: some View {
        let r = size / 2
        ZStack {
            SealBody()
                .fill(Color.waxFill)
                .shadow(color: .black.opacity(0.28), radius: 2, y: 2)
            Circle()
                .stroke(Color.waxRing, lineWidth: max(1, r * 0.05))
                .frame(width: r * 1.06, height: r * 1.06)
            Text("P")
                .font(.system(size: r * 0.62, weight: .bold, design: .serif))
                .foregroundStyle(Color.waxLetter)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-6))
        .accessibilityHidden(true)
    }
}

struct PressedWidgetView: View {
    let entry: PressedEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let card = entry.card {
                content(for: card)
                    .widgetURL(URL(string: "pressed://card/\(card.id.uuidString)?from=widget"))
            } else {
                empty
                    .widgetURL(URL(string: "pressed://stack"))
            }
        }
        .containerBackground(for: .widget) { Color.paper }
    }

    // MARK: Pieces

    private func stampText(for card: WidgetCard) -> String {
        CurlRules.isExpired(dueAt: card.dueAt, now: entry.date)
            ? "CRUMBLING"
            : DueLabel.text(dueAt: card.dueAt, now: entry.date)
    }

    /// Fold size grows as the card nears its due date; an expired card gets the biggest.
    private func foldSize(for card: WidgetCard) -> CGFloat {
        guard let level = CurlRules.level(savedAt: card.savedAt, dueAt: card.dueAt, now: entry.date) else { return 44 }
        return CGFloat(10 + level * 10)
    }

    @ViewBuilder
    private func content(for card: WidgetCard) -> some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text(stampText(for: card)).font(.system(size: 11, weight: .heavy, design: .monospaced))
                Text(card.title).font(.system(size: 13, weight: .semibold, design: .serif)).lineLimit(2)
                Text("\(entry.pendingCount) waiting").font(.system(size: 10, design: .monospaced))
            }
        } else {
            let medium = family == .systemMedium
            VStack(alignment: .leading, spacing: 6) {
                Text(card.kindLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.inkQuiet)
                Text(card.title)
                    .font(.system(size: medium ? 20 : 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                    .lineLimit(medium ? 3 : 4)
                Text(card.site)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkQuiet)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if CurlRules.isExpired(dueAt: card.dueAt, now: entry.date) {
                    Text("Tap to rescue")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.stampRed)
                }
                HStack(alignment: .bottom) {
                    StampView(text: stampText(for: card))
                    Spacer()
                    if medium {
                        Text("\(entry.pendingCount) waiting")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.inkQuiet)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                Fold()
                    .fill(Color.outline)
                    .frame(width: foldSize(for: card), height: foldSize(for: card))
                    .padding(-16)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            if family != .accessoryRectangular {
                WaxSealMark(size: family == .systemMedium ? 56 : 44)
                Spacer(minLength: 0)
            }
            Text("Nothing waiting.")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            Text("The pile is clear. Enjoy it.")
                .font(.system(size: 11))
                .foregroundStyle(Color.inkQuiet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

@main
struct PressedWidget: Widget {
    let kind = "PressedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PressedProvider()) { entry in
            PressedWidgetView(entry: entry)
        }
        .configurationDisplayName("The Pile")
        .description("The links you're avoiding, curling a little more each hour.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
