import Foundation

/// The decision "should distracting apps be locked right now?". Pure, so it can be unit-tested.
enum FocusRules {
    /// The lock window runs from the lock time to the end of the day. DeviceActivity needs at least 15 minutes.
    static let latestLockMinuteOfDay = 23 * 60 + 30
    static let bypassMinutes = 15

    /// A stable per-day key in the user's calendar, such as "2026-11-10".
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func shouldBeLocked(now: Date,
                               enabled: Bool,
                               hasSelection: Bool,
                               lockHour: Int,
                               lockMinute: Int,
                               lastPressedDay: String?,
                               hasPending: Bool,
                               bypassUntil: Date?,
                               calendar: Calendar = .current) -> Bool {
        guard enabled, hasSelection else { return false }
        // Never trap someone with nothing to press.
        guard hasPending else { return false }
        if let bypassUntil, bypassUntil > now { return false }
        if lastPressedDay == dayKey(now, calendar: calendar) { return false }

        let minuteOfDay = min(lockHour * 60 + lockMinute, latestLockMinuteOfDay)
        guard let lockToday = calendar.date(
            bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: now) else { return false }
        return now >= lockToday
    }
}
