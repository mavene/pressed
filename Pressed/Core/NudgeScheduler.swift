import UIKit
import UserNotifications

/// Schedules the evening nudge as local notifications, rebuilt for the next seven days whenever the pile changes.
@MainActor
enum NudgeScheduler {
    static let identifierPrefix = "nudge-"
    static let daysAhead = 7

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    static func rebuild(now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()

        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard AppSettings.nudgeEnabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let pending = CardStore.shared.fetchPending()
        let calendar = Calendar.current
        let dates = NudgeSchedule.fireDates(
            from: now,
            hour: AppSettings.nudgeHour,
            minute: AppSettings.nudgeMinute,
            count: daysAhead,
            calendar: calendar)

        for fireDate in dates {
            guard let message = NudgeCopy.make(pending: pending, fireDate: fireDate) else { continue }
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.userInfo = ["route": "stack"]

            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let identifier = identifierPrefix + String(
                format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    /// Asked once, after the first press, with a short explanation first.
    static func offerPermissionIfNeeded(from presenter: UIViewController) {
        guard !AppSettings.hasAskedForNotifications, AppSettings.nudgeEnabled else { return }
        AppSettings.hasAskedForNotifications = true
        let alert = UIAlertController(
            title: "A gentle evening nudge?",
            message: "Pressed can remind you once a day about links that are about to crumble. Nothing else, and never when your pile is empty.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sounds good", style: .default) { _ in
            Task { @MainActor in
                await requestAuthorization()
                await rebuild()
            }
        })
        presenter.present(alert, animated: true)
    }
}

/// Rebuilds the schedule a moment after anything relevant changes.
@MainActor
final class NudgeCoordinator {
    static let shared = NudgeCoordinator()

    private var pendingWork: DispatchWorkItem?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed), name: .cardsDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed), name: .nudgeSettingsDidChange, object: nil)
        changed()
    }

    @objc private func changed() {
        pendingWork?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor in
                await NudgeScheduler.rebuild()
            }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }
}
