import Foundation

extension Notification.Name {
    /// Posted on the main thread after every change to the cards.
    static let cardsDidChange = Notification.Name("PressedCardsDidChange")
    /// Posted when the nudge time or on/off switch changes.
    static let nudgeSettingsDidChange = Notification.Name("PressedNudgeSettingsDidChange")
}

/// User settings. Stored in the App Group so a future widget can read them.
enum AppSettings {
    private static var defaults: UserDefaults { AppGroup.defaults }

    static var shelfLifeDays: Int {
        get {
            let value = defaults.integer(forKey: "shelfLifeDays")
            return [3, 7, 14].contains(value) ? value : 7
        }
        set { defaults.set(newValue, forKey: "shelfLifeDays") }
    }

    static var nudgeEnabled: Bool {
        get { (defaults.object(forKey: "nudgeEnabled") as? Bool) ?? true }
        set { defaults.set(newValue, forKey: "nudgeEnabled") }
    }

    static var nudgeHour: Int {
        get { (defaults.object(forKey: "nudgeHour") as? Int) ?? 19 }
        set { defaults.set(newValue, forKey: "nudgeHour") }
    }

    static var nudgeMinute: Int {
        get { (defaults.object(forKey: "nudgeMinute") as? Int) ?? 0 }
        set { defaults.set(newValue, forKey: "nudgeMinute") }
    }

    static var hasOnboarded: Bool {
        get { defaults.bool(forKey: "hasOnboarded") }
        set { defaults.set(newValue, forKey: "hasOnboarded") }
    }

    static var hasAskedForNotifications: Bool {
        get { defaults.bool(forKey: "hasAskedForNotifications") }
        set { defaults.set(newValue, forKey: "hasAskedForNotifications") }
    }

    static var hasOfferedFocus: Bool {
        get { defaults.bool(forKey: "hasOfferedFocus") }
        set { defaults.set(newValue, forKey: "hasOfferedFocus") }
    }
}
