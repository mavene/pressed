import CoreData
import WidgetKit

/// All card reads and writes on the main-queue context. Every save posts `.cardsDidChange`.
@MainActor
final class CardStore {
    static let shared = CardStore(context: PersistenceController.shared.viewContext)

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: Reading

    private func fetchCards(status: CardStatus? = nil,
                            predicate extra: NSPredicate? = nil,
                            sort: [NSSortDescriptor] = []) -> [Card] {
        let request = NSFetchRequest<Card>(entityName: "Card")
        var predicates: [NSPredicate] = []
        if let status {
            predicates.append(NSPredicate(format: "statusRaw == %@", NSNumber(value: status.rawValue)))
        }
        if let extra { predicates.append(extra) }
        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = sort
        return (try? context.fetch(request)) ?? []
    }

    private func card(_ id: UUID) -> Card? {
        fetchCards(predicate: NSPredicate(format: "id == %@", id as CVarArg)).first
    }

    /// Pending cards, soonest due first (that is, most curled first).
    func fetchPending() -> [CardRecord] {
        fetchCards(status: .pending, sort: [NSSortDescriptor(key: "dueAt", ascending: true)])
            .compactMap { $0.record }
    }

    /// Pressed cards, newest first.
    func fetchPressed() -> [CardRecord] {
        fetchCards(status: .pressed, sort: [NSSortDescriptor(key: "pressedAt", ascending: false)])
            .compactMap { $0.record }
    }

    func fetchRecord(id: UUID) -> CardRecord? {
        card(id)?.record
    }

    func counts() -> (pending: Int, pressed: Int, crumbled: Int) {
        func count(_ status: CardStatus) -> Int {
            let request = NSFetchRequest<Card>(entityName: "Card")
            request.predicate = NSPredicate(format: "statusRaw == %@", NSNumber(value: status.rawValue))
            return (try? context.count(for: request)) ?? 0
        }
        return (count(.pending), count(.pressed), count(.crumbled))
    }

    /// Position of a pressed card in the order things were pressed ("NO. 07").
    func pressedNumber(for record: CardRecord) -> Int {
        guard let pressedAt = record.pressedAt else { return 0 }
        return fetchCards(status: .pressed,
                          predicate: NSPredicate(format: "pressedAt <= %@", pressedAt as NSDate)).count
    }

    // MARK: Saving links

    @discardableResult
    func add(url: URL, savedAt: Date = Date(), id: UUID = UUID(), sealSeed: Int32? = nil) -> CardRecord? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }

        // Saving the same link twice keeps the first card.
        let duplicate = fetchCards(
            status: .pending,
            predicate: NSPredicate(format: "urlString == %@", url.absoluteString)).first
        if let duplicate { return duplicate.record }

        guard let card = NSEntityDescription.insertNewObject(forEntityName: "Card", into: context) as? Card else {
            return nil
        }
        card.id = id
        card.urlString = url.absoluteString
        card.kindRaw = KindDetector.detect(url: url).rawValue
        card.savedAt = savedAt
        card.dueAt = savedAt.addingTimeInterval(Double(AppSettings.shelfLifeDays) * 86_400)
        card.statusRaw = CardStatus.pending.rawValue
        card.finishRaw = CardFinish.none.rawValue
        card.sealSeed = sealSeed ?? Int32.random(in: 0..<10_000)
        save()
        return card.record
    }

    /// Moves everything the share extension saved into Core Data.
    @discardableResult
    func ingestInbox() -> Int {
        var added = 0
        for entry in Inbox.readAll() {
            if let url = URL(string: entry.item.urlString),
               add(url: url, savedAt: entry.item.savedAt, id: entry.item.id, sealSeed: entry.item.sealSeed) != nil {
                added += 1
            }
            try? FileManager.default.removeItem(at: entry.file)
        }
        return added
    }

    func updateMetadata(id: UUID, result: MetadataResult) {
        guard let card = card(id) else { return }
        if let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            card.title = title
        }
        if let site = result.siteName, !site.isEmpty { card.siteName = site }
        if let image = result.imageData { card.imageData = image }
        card.kindRaw = result.kind.rawValue
        if let minutes = result.estMinutes { card.estMinutes = Int16(clamping: minutes) }
        save()
    }

    // MARK: Press, crumble, rescue

    func press(id: UUID, note: String?, now: Date = Date()) -> CardRecord? {
        guard let card = card(id),
              CardStatus(rawValue: card.statusRaw) == .pending,
              let savedAt = card.savedAt,
              let dueAt = card.dueAt else { return nil }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        card.statusRaw = CardStatus.pressed.rawValue
        card.pressedAt = now
        card.note = (trimmed?.isEmpty ?? true) ? nil : trimmed
        card.finishRaw = FinishRules.finish(
            savedAt: savedAt,
            pressedAt: now,
            dueAt: dueAt,
            estMinutes: card.estMinutes > 0 ? Int(card.estMinutes) : nil,
            rescued: card.rescuedAt != nil
        ).rawValue
        save()
        return card.record
    }

    func crumble(id: UUID, now: Date = Date()) {
        guard let card = card(id), CardStatus(rawValue: card.statusRaw) == .pending else { return }
        card.statusRaw = CardStatus.crumbled.rawValue
        card.crumbledAt = now
        save()
    }

    /// Pending cards whose due date has passed. They are still on screen until swept.
    func expiredPending(now: Date = Date()) -> [CardRecord] {
        fetchCards(status: .pending, predicate: NSPredicate(format: "dueAt <= %@", now as NSDate))
            .compactMap { $0.record }
    }

    /// Marks every expired pending card as crumbled and returns them.
    @discardableResult
    func sweepExpired(now: Date = Date()) -> [CardRecord] {
        let expired = fetchCards(status: .pending, predicate: NSPredicate(format: "dueAt <= %@", now as NSDate))
        guard !expired.isEmpty else { return [] }
        let records = expired.compactMap { $0.record }
        for card in expired {
            card.statusRaw = CardStatus.crumbled.rawValue
            card.crumbledAt = now
        }
        save()
        return records
    }

    /// Pushes the due date back by three days, once per card.
    func rescue(id: UUID, now: Date = Date()) -> CardRecord? {
        guard let card = card(id),
              CardStatus(rawValue: card.statusRaw) == .pending,
              card.rescuedAt == nil,
              let dueAt = card.dueAt, dueAt > now else { return nil }
        card.dueAt = dueAt.addingTimeInterval(3 * 86_400)
        card.rescuedAt = now
        save()
        return card.record
    }

    func delete(id: UUID) {
        guard let card = card(id) else { return }
        context.delete(card)
        save()
    }

    // MARK: Saving

    fileprivate func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Saving cards failed: \(error)")
        }
        NotificationCenter.default.post(name: .cardsDidChange, object: nil)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#if DEBUG
/// Helpers for trying the curl and crumble without waiting a week.
extension CardStore {
    func debugAddSamples() {
        let samples = [
            "https://en.wikipedia.org/wiki/Paper",
            "https://www.youtube.com/watch?v=jNQXAC9IVRw",
            "https://www.bbcgoodfood.com/recipes/easy-focaccia",
            "https://en.wikipedia.org/wiki/Bookmark",
            "https://en.wikipedia.org/wiki/Origami",
            "https://podcasts.apple.com/us/podcast/99-percent-invisible/id394775318"
        ]
        for (index, text) in samples.enumerated() {
            guard let url = URL(string: text) else { continue }
            add(url: url, savedAt: Date().addingTimeInterval(-Double(index) * 1.4 * 86_400))
        }
    }

    /// Moves every pending card one day further along its life.
    func debugAge(days: Double) {
        for card in fetchCards(status: .pending) {
            if let saved = card.savedAt { card.savedAt = saved.addingTimeInterval(-days * 86_400) }
            if let due = card.dueAt { card.dueAt = due.addingTimeInterval(-days * 86_400) }
        }
        save()
    }
}
#endif
