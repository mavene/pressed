import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The grayed-out screen, in Pressed's paper look.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let desk = UIColor(red: 0xED / 255, green: 0xE5 / 255, blue: 0xD6 / 255, alpha: 1)
    private let paper = UIColor(red: 0xFB / 255, green: 0xF8 / 255, blue: 0xF1 / 255, alpha: 1)
    private let ink = UIColor(red: 0x23 / 255, green: 0x1E / 255, blue: 0x18 / 255, alpha: 1)
    private let inkSoft = UIColor(red: 0x4E / 255, green: 0x44 / 255, blue: 0x38 / 255, alpha: 1)

    private func make() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: desk,
            icon: UIImage(systemName: "seal.fill")?.withTintColor(ink, renderingMode: .alwaysOriginal),
            title: .init(text: "Press one link first.", color: ink),
            subtitle: .init(text: "Open Pressed and press one link from tonight\u{2019}s stack. Then this opens up.",
                            color: inkSoft),
            primaryButtonLabel: .init(text: "Open Pressed", color: paper),
            primaryButtonBackgroundColor: ink,
            secondaryButtonLabel: .init(text: "Not now (15 min)", color: ink))
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration { make() }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration { make() }
}
