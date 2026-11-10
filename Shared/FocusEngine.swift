import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Puts a shield over, or takes it off, the chosen apps.
protocol FocusShield {
    func apply(_ selection: FamilyActivitySelection)
    func clear()
}

/// The real thing: ManagedSettings grays the apps out behind the shield screen.
struct SystemShield: FocusShield {
    private let store = ManagedSettingsStore()

    func apply(_ selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        // Websites ticked in Apple's picker are deliberately ignored: Focus mode locks apps and categories only.
        store.shield.webDomains = nil
    }

    func clear() {
        store.clearAllSettings()
    }
}

/// The Simulator can't show the picker or shields, so it only records a flag the Settings screen can show.
struct SimulatedShield: FocusShield {
    func apply(_ selection: FamilyActivitySelection) { FocusStore.simulatedLocked = true }
    func clear() { FocusStore.simulatedLocked = false }
}

enum FocusShields {
    static let isSimulated: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    static var current: FocusShield { isSimulated ? SimulatedShield() : SystemShield() }
}

/// Decides and applies. Called by the app and by the DeviceActivity monitor.
enum FocusEngine {
    static var hasSelection: Bool {
        // The Simulator has no picker, so it pretends something is chosen.
        if FocusShields.isSimulated { return true }
        guard let selection = FocusStore.selection else { return false }
        return !(selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty)
    }

    /// Whether the lock should be on right now, without touching the shield.
    static func shouldLockNow(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hasSelection = hasSelection
        return FocusStore.enabled && hasSelection && (
            FocusStore.debugForced
            || FocusRules.shouldBeLocked(
                now: now,
                enabled: true,
                hasSelection: hasSelection,
                lockHour: FocusStore.lockHour,
                lockMinute: FocusStore.lockMinute,
                lastPressedDay: FocusStore.lastPressedDay,
                hasPending: FocusStore.hasPending,
                bypassUntil: FocusStore.bypassUntil,
                calendar: calendar))
    }

    @discardableResult
    static func evaluate(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let locked = shouldLockNow(now: now, calendar: calendar)
        if locked {
            FocusShields.current.apply(FocusStore.selection ?? FamilyActivitySelection())
        } else {
            FocusShields.current.clear()
        }
        return locked
    }
}

/// DeviceActivity schedules, so the monitor extension can lock and unlock while Pressed isn't running.
enum FocusSchedule {
    static let dailyName = DeviceActivityName("focus.daily")
    static let bypassName = DeviceActivityName("focus.bypass")

    /// Every day from the lock time to the end of the day.
    static func startDaily(hour: Int, minute: Int) {
        let minuteOfDay = min(hour * 60 + minute, FocusRules.latestLockMinuteOfDay)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true)
        try? DeviceActivityCenter().startMonitoring(dailyName, during: schedule)
    }

    static func stopAll() {
        DeviceActivityCenter().stopMonitoring()
    }

    /// One-off window after "Not now"; its end re-applies the shield.
    static func startBypass(minutes: Int = FocusRules.bypassMinutes, now: Date = Date(), calendar: Calendar = .current) {
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        // Past midnight the daily window has ended anyway, so there is nothing to re-lock.
        guard calendar.isDate(now, inSameDayAs: end) else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: end),
            repeats: false)
        try? DeviceActivityCenter().startMonitoring(bypassName, during: schedule)
    }
}
