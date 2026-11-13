import UIKit
import UniformTypeIdentifiers
import WidgetKit

/// Share sheet entry: stores the link in the App Group folder and closes.
final class ShareViewController: UIViewController {
    private let badge = UIView()
    private let iconView = UIImageView()
    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)

        badge.backgroundColor = UIColor(red: 0.93, green: 0.90, blue: 0.84, alpha: 1)
        badge.layer.cornerRadius = 22
        badge.alpha = 0
        badge.translatesAutoresizingMaskIntoConstraints = false

        iconView.tintColor = UIColor(red: 0.14, green: 0.12, blue: 0.09, alpha: 1)
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(systemName: "bookmark.fill")
        iconView.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.text = "Saving\u{2026}"
        messageLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        messageLabel.textColor = UIColor(red: 0.14, green: 0.12, blue: 0.09, alpha: 1)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(badge)
        badge.addSubview(iconView)
        badge.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 190),
            iconView.topAnchor.constraint(equalTo: badge.topAnchor, constant: 22),
            iconView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34),
            messageLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -22)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.2) { self.badge.alpha = 1 }
        Task { await save() }
    }

    // MARK: Saving

    private func save() async {
        guard let url = await findURL() else {
            show("No link found", symbol: "exclamationmark.circle.fill")
            finish(after: 1.4, cancelled: true)
            return
        }
        let item = InboxItem(
            id: UUID(),
            urlString: url.absoluteString,
            savedAt: Date(),
            sealSeed: Int32.random(in: 0..<10_000))
        do {
            try Inbox.write(item)
            // The widget also reads the Inbox, so it can show the link before the app has imported it.
            WidgetCenter.shared.reloadAllTimelines()
            show("Saved", symbol: "checkmark.circle.fill")
            finish(after: 0.9, cancelled: false)
        } catch {
            show("Couldn\u{2019}t save. Open Pressed once, then try again.", symbol: "exclamationmark.circle.fill")
            finish(after: 2.0, cancelled: true)
        }
    }

    private func show(_ text: String, symbol: String) {
        messageLabel.text = text
        iconView.image = UIImage(systemName: symbol)
    }

    private func finish(after delay: TimeInterval, cancelled: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            if cancelled {
                self?.extensionContext?.cancelRequest(withError: NSError(domain: "Pressed", code: 1))
            } else {
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    // MARK: Finding the link

    private func findURL() async -> URL? {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let item = await loadItem(provider, type: UTType.url)
            if let url = item as? URL, isWeb(url) { return url }
            if let text = item as? String, let url = URL(string: text), isWeb(url) { return url }
        }
        // Some apps share the link inside plain text.
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let item = await loadItem(provider, type: UTType.plainText)
            if let text = item as? String, let url = firstLink(in: text) { return url }
        }
        return nil
    }

    private func loadItem(_ provider: NSItemProvider, type: UTType) async -> Any? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Any?, Never>) in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    private func isWeb(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func firstLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range)
            .compactMap { $0.url }
            .first(where: { isWeb($0) })
    }
}
