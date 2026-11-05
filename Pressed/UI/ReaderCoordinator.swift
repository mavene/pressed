import UIKit
import SafariServices

/// Opens a link in Safari's in-app view and shows the press sheet when it closes.
@MainActor
final class ReaderCoordinator: NSObject, SFSafariViewControllerDelegate {
    private static var current: ReaderCoordinator?

    private let cardID: UUID
    private weak var presenter: UIViewController?

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

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        let id = cardID
        let presenter = self.presenter
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
                    NudgeScheduler.offerPermissionIfNeeded(from: presenter)
                }
            }
            presenter.present(press, animated: true)
        }
    }
}
