import UIKit
import FamilyControls

/// Focus mode, app side: asks permission, keeps the lock in step with the rules, and unlocks on a press.
@MainActor
enum FocusController {
    static var isAuthorized: Bool {
        FocusShields.isSimulated || AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Asks for Screen Time access for this iPhone's owner. Throws if the Family Controls entitlement is missing.
    static func requestAuthorization() async throws {
        if FocusShields.isSimulated { return }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    /// Brings the shield and the daily schedule in line with the current settings.
    static func sync(now: Date = Date()) {
        FocusStore.hasPending = !CardStore.shared.fetchPending().isEmpty
        // If the user revoked access in Settings, the shield can no longer be managed.
        if FocusStore.enabled && !isAuthorized {
            FocusStore.enabled = false
        }
        if FocusStore.enabled {
            FocusSchedule.startDaily(hour: FocusStore.lockHour, minute: FocusStore.lockMinute)
        } else {
            FocusSchedule.stopAll()
        }
        FocusEngine.evaluate(now: now)
    }

    /// Any press counts as today's press and lifts the lock.
    static func cardPressed(now: Date = Date()) {
        FocusStore.lastPressedDay = FocusRules.dayKey(now)
        FocusStore.bypassUntil = nil
        FocusStore.debugForced = false
        sync(now: now)
    }

    /// Lifts the lock for 15 minutes, the same as "Not now" on the shield. The monitor re-locks afterwards.
    static func grantBypass(now: Date = Date()) {
        FocusStore.bypassUntil = now.addingTimeInterval(TimeInterval(FocusRules.bypassMinutes * 60))
        FocusSchedule.startBypass(now: now)
        FocusEngine.evaluate(now: now)
    }

    static var isLockedNow: Bool { FocusEngine.shouldLockNow() }

    static func disable() {
        FocusStore.enabled = false
        FocusStore.debugForced = false
        sync()
    }

    static var statusLine: String {
        guard FocusStore.enabled else {
            return "Distracting apps stay locked from your chosen time until you press a link from tonight\u{2019}s stack. Only the apps you pick. Everything stays on this iPhone."
        }
        let locked = FocusShields.isSimulated ? FocusStore.simulatedLocked : FocusEngine.evaluate()
        let prefix = FocusShields.isSimulated ? "Simulator: " : ""
        if locked { return prefix + "Locked now. Press a link to open your apps up." }
        if FocusStore.lastPressedDay == FocusRules.dayKey(Date()) { return prefix + "You\u{2019}ve pressed today, so your apps are open." }
        return prefix + "Locks at your chosen time, if you have something to press."
    }

    static func selectionSummary() -> String {
        guard let selection = FocusStore.selection else {
            return FocusShields.isSimulated ? "Simulated" : "None yet"
        }
        var parts: [String] = []
        if !selection.applicationTokens.isEmpty { parts.append("\(selection.applicationTokens.count) apps") }
        if !selection.categoryTokens.isEmpty { parts.append("\(selection.categoryTokens.count) categories") }
        return parts.isEmpty ? "None yet" : parts.joined(separator: ", ")
    }

    #if DEBUG
    static func debugLock() {
        FocusStore.debugForced = true
        FocusStore.bypassUntil = nil
        FocusEngine.evaluate()
    }

    /// Lifts the lock for 15 minutes, like "Not now" on the shield.
    static func debugUnlock() {
        FocusStore.debugForced = false
        FocusStore.bypassUntil = Date().addingTimeInterval(TimeInterval(FocusRules.bypassMinutes * 60))
        FocusEngine.evaluate()
    }
    #endif
}

/// Keeps Focus mode in step when cards change or the app comes back to the front.
@MainActor
final class FocusCoordinator {
    static let shared = FocusCoordinator()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed), name: .cardsDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed), name: UIApplication.didBecomeActiveNotification, object: nil)
        changed()
    }

    @objc private func changed() {
        FocusController.sync()
    }
}
