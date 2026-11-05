import Foundation

struct StackResult: Equatable {
    var cards: [CardRecord]
    var totalMinutes: Int
}

/// Picks the cards for Tonight's Stack. Pure function so it can be unit-tested.
enum StackPicker {
    static let defaultMinutes = 10

    static func minutes(for card: CardRecord) -> Int {
        let value = card.estMinutes ?? 0
        return value > 0 ? value : defaultMinutes
    }

    /// - Parameters:
    ///   - pending: pending cards in any order.
    ///   - budgetMinutes: nil means no time limit.
    ///   - maxCount: how many cards at most.
    static func pick(from pending: [CardRecord], budgetMinutes: Int?, maxCount: Int = 3) -> StackResult {
        let sorted = pending
            .filter { $0.status == .pending }
            .sorted { lhs, rhs in
                if lhs.dueAt != rhs.dueAt { return lhs.dueAt < rhs.dueAt }
                return lhs.savedAt < rhs.savedAt
            }
        guard !sorted.isEmpty else { return StackResult(cards: [], totalMinutes: 0) }

        let window = Array(sorted.prefix(6))
        var chosen: [CardRecord] = []
        var total = 0

        func fits(_ card: CardRecord) -> Bool {
            guard let budget = budgetMinutes else { return true }
            return total + minutes(for: card) <= budget
        }

        for card in sorted where chosen.count < maxCount {
            guard fits(card) else { continue }
            // Variety: avoid a third card of the same kind when another kind is available.
            if chosen.count == 2,
               chosen[0].kind == chosen[1].kind,
               chosen[1].kind == card.kind,
               window.contains(where: { other in
                   other.kind != card.kind
                       && !chosen.contains(where: { $0.id == other.id })
                       && fits(other)
               }) {
                continue
            }
            chosen.append(card)
            total += minutes(for: card)
        }

        if chosen.isEmpty, let first = sorted.first {
            return StackResult(cards: [first], totalMinutes: minutes(for: first))
        }
        return StackResult(cards: chosen, totalMinutes: total)
    }
}
