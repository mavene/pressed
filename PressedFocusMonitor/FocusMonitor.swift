import DeviceActivity
import Foundation

/// Runs without Pressed being open: locks when the daily window starts and lifts the shield when it ends.
final class FocusMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // The "Not now" window starting must not lock anything.
        guard activity == FocusSchedule.dailyName else { return }
        FocusEngine.evaluate()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == FocusSchedule.bypassName {
            // The 15 minutes are up: lock again if the day's press still hasn't happened.
            FocusStore.bypassUntil = nil
            FocusEngine.evaluate()
        } else {
            // End of the day: the lock expires.
            FocusShields.current.clear()
        }
    }
}
