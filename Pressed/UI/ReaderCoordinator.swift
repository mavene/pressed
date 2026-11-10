import UIKit
import SafariServices

/// Opens a link in Safari's in-app view and shows the press sheet when it closes.
@MainActor
final class ReaderCoordinator: NSObject, SFSafariViewControllerDelegate {
    private static var current: ReaderCoordinator?

    /// Shorter than this, or a page that never loaded, doesn't count as reading.
    static let minimumReadSeconds: TimeInterval = 5

    /// Pure, so it can be unit-tested.
    static func countsAsRead(loaded: Bool, seconds: TimeInterval) -> Bool {
        loaded && seconds >= minimumReadSeconds
    }

    private let cardID: UUID
    private weak var presenter: UIViewController?
    private let openedAt = Date()
    private var didLoad = false

    private init(cardID: UUID, presenter: UIViewController) {
        self.cardID = cardID
        self.presenter = presenter
        super.init()
    }

    static func open(_ record: CardRecord, from presenter: UIViewController) {
        guard let scheme = record.url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            UIApplication.shared.open(record.url)
            return
        }
        let coordinator = ReaderCoordinator(cardID: record.id, presenter: presenter)
        current = coordinator

        let safari = SFSafariViewController(url: record.url)
        safari.preferredControlTintColor = Theme.ink
        safari.preferredBarTintColor = Theme.tabBar
        safari.dismissButtonStyle = .done
        safari.delegate = coordinator
        presenter.present(safari, animated: true)
    }

    private static func offerBypass(for record: CardRecord, from presenter: UIViewController) {
        // Wait for Safari's dismissal to finish before presenting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let alert = UIAlertController(
                title: "Stuck behind the lock?",
                message: "This link may open in an app that Focus mode is locking. Unlock your apps for 15 minutes to read it? The lock comes back afterwards.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
            alert.addAction(UIAlertAction(title: "Unlock for 15 min", style: .default) { _ in
                FocusController.grantBypass()
                ReaderCoordinator.open(record, from: presenter)
            })
            presenter.present(alert, animated: true)
        }
    }

    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        didLoad = didLoadSuccessfully
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        let id = cardID
        let presenter = self.presenter
        // A link that handed off to another app (for example a locked one) or never loaded wasn't read.
        // Leave the card pending instead of asking to press it.
        guard Self.countsAsRead(loaded: didLoad, seconds: Date().timeIntervalSince(openedAt)) else {
            ReaderCoordinator.current = nil
            guard let presenter else { return }
            if FocusController.isLockedNow, let record = CardStore.shared.fetchRecord(id: id), record.status == .pending {
                // Likely stuck: the link wants an app that Focus mode is locking. Offer the way out.
                Self.offerBypass(for: record, from: presenter)
            } else {
                Toast.show("Still on your pile", in: presenter.view)
            }
            return
        }
        // Give Safari's dismissal a moment to finish before presenting the sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            ReaderCoordinator.current = nil
            guard let presenter,
                  let record = CardStore.shared.fetchRecord(id: id),
                  record.status == .pending else { return }

            let press = PressViewController(card: record)
            press.onFinish = { [weak presenter] pressed in
                guard let presenter, pressed != nil else { return }
                Toast.show("Pressed. It\u{2019}s on your Shelf.", in: presenter.view)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    // One question at a time: the Focus offer waits if the nudge question is being asked.
                    let nudgeAsks = !AppSettings.hasAskedForNotifications && AppSettings.nudgeEnabled
                    NudgeScheduler.offerPermissionIfNeeded(from: presenter)
                    if !nudgeAsks { FocusSetup.offerIfNeeded(from: presenter) }
                }
            }
            presenter.present(press, animated: true)
        }
    }
}
