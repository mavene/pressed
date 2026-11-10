import Foundation
import FamilyControls

/// Focus-mode state kept in the App Group, so the app and the Focus extensions see the same values.
enum FocusStore {
    private static var defaults: UserDefaults { AppGroup.defaults }

    static var enabled: Bool {
        get { defaults.bool(forKey: "focusEnabled") }
        set { defaults.set(newValue, forKey: "focusEnabled") }
    }

    static var lockHour: Int {
        get { (defaults.object(forKey: "focusLockHour") as? Int) ?? 20 }
        set { defaults.set(newValue, forKey: "focusLockHour") }
    }

    static var lockMinute: Int {
        get { (defaults.object(forKey: "focusLockMinute") as? Int) ?? 0 }
        set { defaults.set(newValue, forKey: "focusLockMinute") }
    }

    /// Day key of the last press, see `FocusRules.dayKey`.
    static var lastPressedDay: String? {
        get { defaults.string(forKey: "focusLastPressedDay") }
        set { defaults.set(newValue, forKey: "focusLastPressedDay") }
    }

    /// "Not now" on the shield: no lock until this moment.
    static var bypassUntil: Date? {
        get { defaults.object(forKey: "focusBypassUntil") as? Date }
        set { defaults.set(newValue, forKey: "focusBypassUntil") }
    }

    /// Whether there is anything to press. Written by the app; the extensions can't open Core Data cheaply.
    static var hasPending: Bool {
        get { defaults.bool(forKey: "focusHasPending") }
        set { defaults.set(newValue, forKey: "focusHasPending") }
    }

    /// Debug builds only: lock regardless of the schedule.
    static var debugForced: Bool {
        get { defaults.bool(forKey: "focusDebugForced") }
        set { defaults.set(newValue, forKey: "focusDebugForced") }
    }

    /// Simulator stand-in for the real shield.
    static var simulatedLocked: Bool {
        get { defaults.bool(forKey: "focusSimulatedLocked") }
        set { defaults.set(newValue, forKey: "focusSimulatedLocked") }
    }

    /// The apps, categories and websites the user chose. Apple hands out opaque tokens, never names.
    static var selection: FamilyActivitySelection? {
        get {
            guard let data = defaults.data(forKey: "focusSelection") else { return nil }
            return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "focusSelection")
            } else {
                defaults.removeObject(forKey: "focusSelection")
            }
        }
    }
}
