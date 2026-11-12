import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
    }
}

/// Colours and type: system serif titles, monospace dates, SF body.
enum Theme {
    static let desk = UIColor(hex: 0xEDE5D6)
    static let sheet = UIColor(hex: 0xF5EFE3)
    static let tabBar = UIColor(hex: 0xF5EFE3)
    static let hairline = UIColor(hex: 0xD6CAB5)
    static let outline = UIColor(hex: 0xCDBFA9)

    static let ink = UIColor(hex: 0x231E18)
    static let inkSoft = UIColor(hex: 0x4E4438)
    static let inkQuiet = UIColor(hex: 0x62574A)

    static let paper0 = UIColor(hex: 0xFBF8F1)
    static let stampRed = UIColor(hex: 0x8E2A20)
    static let rail = UIColor(hex: 0x8B6A47)
    static let brass = UIColor(hex: 0xA88442)

    // MARK: Fonts

    static func serif(_ size: CGFloat,
                      _ weight: UIFont.Weight = .semibold,
                      style: UIFont.TextStyle = .body,
                      italic: Bool = false,
                      scaled: Bool = true) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        var descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        if italic, let slanted = descriptor.withSymbolicTraits(.traitItalic) {
            descriptor = slanted
        }
        let font = UIFont(descriptor: descriptor, size: size)
        return scaled ? UIFontMetrics(forTextStyle: style).scaledFont(for: font) : font
    }

    static func mono(_ size: CGFloat,
                     _ weight: UIFont.Weight = .regular,
                     style: UIFont.TextStyle = .footnote,
                     scaled: Bool = true) -> UIFont {
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        return scaled ? UIFontMetrics(forTextStyle: style).scaledFont(for: font) : font
    }

    static func sans(_ size: CGFloat,
                     _ weight: UIFont.Weight = .regular,
                     style: UIFont.TextStyle = .body,
                     scaled: Bool = true) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return scaled ? UIFontMetrics(forTextStyle: style).scaledFont(for: font) : font
    }
}

// MARK: - Bookmark kinds

extension CardKind {
    var symbolName: String {
        switch self {
        case .article: return "doc.text"
        case .video: return "play.fill"
        case .podcast: return "headphones"
        case .tweet: return "quote.bubble"
        }
    }

    /// Placeholder block colour when a link has no picture.
    var blockColor: UIColor {
        switch self {
        case .article: return UIColor(hex: 0xA9BCC4)
        case .video: return UIColor(hex: 0x2E2924)
        case .podcast: return UIColor(hex: 0xB8C9D1)
        case .tweet: return UIColor(hex: 0xF3DF8E)
        }
    }

    var blockSymbolColor: UIColor {
        self == .video ? UIColor(hex: 0xF7EFDB) : Theme.ink
    }
}

// MARK: - Haptics

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// The seal landing.
    static func thunk() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
