import ManagedSettings
import UserNotifications
import Foundation

/// Handles the two shield buttons. A shield can't open Pressed itself, so "Open Pressed" posts a notification to tap.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            let content = UNMutableNotificationContent()
            content.title = "Press one link"
            content.body = "Tap to open tonight\u{2019}s stack."
            content.sound = .default
            content.userInfo = ["route": "stack"]
            let request = UNNotificationRequest(
                identifier: "focus-open",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            UNUserNotificationCenter.current().add(request) { _ in completionHandler(.close) }

        case .secondaryButtonPressed:
            FocusStore.bypassUntil = Date().addingTimeInterval(TimeInterval(FocusRules.bypassMinutes * 60))
            FocusShields.current.clear()
            FocusSchedule.startBypass()
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }
}
