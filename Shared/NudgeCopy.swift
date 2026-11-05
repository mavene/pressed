import Foundation

struct NudgeMessage: Equatable {
    let title: String
    let body: String
}

/// Wording for the evening notification. Plain and guilt-free.
enum NudgeCopy {
    /// Builds the message as it would read at `fireDate`, assuming nothing is read in between.
    /// Returns nil when nothing would be left waiting, so no notification is scheduled.
    static func make(pending: [CardRecord], fireDate: Date) -> NudgeMessage? {
        let alive = pending.filter { $0.status == .pending && $0.dueAt > fireDate }
        guard !alive.isEmpty else { return nil }

        let urgent = alive.filter { $0.dueAt.timeIntervalSince(fireDate) <= 24 * 3600 }
        if urgent.count == 1, let card = urgent.first {
            return NudgeMessage(title: "Pressed", body: "\u{201C}\(card.displayTitle)\u{201D} crumbles tomorrow.")
        }
        if urgent.count > 1 {
            return NudgeMessage(title: "Pressed", body: "\(urgent.count) cards crumble tomorrow. Got a few minutes?")
        }

        let curling = alive.filter {
            (CurlRules.level(savedAt: $0.savedAt, dueAt: $0.dueAt, now: fireDate) ?? 3) >= 1
        }
        if !curling.isEmpty {
            let verb = curling.count == 1 ? "link is" : "links are"
            return NudgeMessage(title: "Pressed", body: "\(curling.count) \(verb) curling. Got 15 minutes?")
        }
        return NudgeMessage(title: "Pressed", body: "\(alive.count) waiting in your pile. A few minutes tonight?")
    }
}

enum NudgeSchedule {
    /// The next `count` occurrences of hour:minute that are still in the future.
    static func fireDates(from now: Date,
                          hour: Int,
                          minute: Int,
                          count: Int,
                          calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = []
        var day = calendar.startOfDay(for: now)
        var guardCounter = 0
        while dates.count < count && guardCounter < count + 3 {
            if let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
               candidate > now {
                dates.append(candidate)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            guardCounter += 1
        }
        return dates
    }
}
