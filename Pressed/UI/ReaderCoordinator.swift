import UIKit
import SafariServices
import os

/// Opens a link in Safari's in-app view and shows the press sheet when it closes, or when the user comes back to
/// Pressed after the link handed off to another app.
@MainActor
final class ReaderCoordinator: NSObject, SFSafariViewControllerDelegate {
    private static var current: ReaderCoordinator?
    private static let log = Logger(subsystem: "com.paradimn.pressed", category: "reader")

    /// Shorter than this, or a page that never loaded, doesn't count as reading.
    static let minimumReadSeconds: TimeInterval = 5

    /// A link that handed off to another app (a podcast, a video) needs longer than a page: you have to go and use it.
    static let minimumHandoffSeconds: TimeInterval = 0 // TEMPORARY: 0 for debugging, normally 5-10

    /// Pure, so it can be unit-tested. When the link was allowed to hand off to another app, the page may never
    /// load in Safari, so the time away counts instead, against the longer minimum.
    static func countsAsRead(loaded: Bool, seconds: TimeInterval, handoffAllowed: Bool = false) -> Bool {
        // A page that loaded and then handed off (a podcast page that opens its app) is a handoff too, so it is
        // never held to more than the handoff minimum.
        if loaded {
            return seconds >= (handoffAllowed ? min(minimumReadSeconds, minimumHandoffSeconds) : minimumReadSeconds)
        }
        return handoffAllowed && seconds >= minimumHandoffSeconds
    }

    /// Pure, so it can be unit-tested. Coming back to Pressed after at least `minimumHandoffSeconds` away, from a
    /// link that was allowed to hand off, means the user went and used the other app.
    static func returnedFromHandoff(handoffAllowed: Bool, awaySeconds: TimeInterval) -> Bool {
        handoffAllowed && awaySeconds >= minimumHandoffSeconds
    }

    private let cardID: UUID
    private weak var presenter: UIViewController?
    private let openedAt = Date()
    private let handoffAllowed: Bool
    private var didLoad = false
    private weak var safari: SFSafariViewController?
    private var finished = false

    // Handoff tracking. When a link opens another app, iOS closes the reader straight away, so "finished" can arrive
    // before the user has done anything. Keep watching, and decide when they come back.
    private var awayAt: Date?
    private var lastAway: TimeInterval?
    private var readerClosed = false
    private var announcedNoRead = false
    private var observers: [NSObjectProtocol] = []

    private init(cardID: UUID, presenter: UIViewController, handoffAllowed: Bool) {
        self.cardID = cardID
        self.presenter = presenter
        self.handoffAllowed = handoffAllowed
        super.init()
    }

    static func open(_ record: CardRecord, from presenter: UIViewController) {
        // Focus mode: unlock before the link opens, so a handoff to a locked app lands on an open app.
        let handoffAllowed = record.status == .pending && FocusController.openingLink(of: record.kind)
        guard let scheme = record.url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            UIApplication.shared.open(record.url)
            return
        }
        let coordinator = ReaderCoordinator(cardID: record.id, presenter: presenter, handoffAllowed: handoffAllowed)
        current = coordinator

        let safari = SFSafariViewController(url: record.url)
        safari.preferredControlTintColor = Theme.ink
        safari.preferredBarTintColor = Theme.tabBar
        safari.dismissButtonStyle = .done
        safari.delegate = coordinator
        coordinator.safari = safari
        presenter.present(safari, animated: true)
        log.debug("opened \(record.kind.label, privacy: .public): handoffAllowed=\(handoffAllowed)")
        coordinator.debugNote(handoffAllowed ? "opened: handoff allowed" : "opened: handoff NOT allowed (lock off?)")
        if handoffAllowed { coordinator.watchForReturn() }
    }

    #if DEBUG
    /// Debug builds only: shows what the handoff logic is doing as a toast, so a device test can be read off the screen.
    private func debugNote(_ text: String) {
        Self.log.debug("\(text, privacy: .public)")
        if let window = presenter?.view.window { Toast.show("[debug] " + text, in: window) }
    }
    #else
    private func debugNote(_ text: String) {}
    #endif

    #if DEBUG
    /// Debug builds only: does what iOS does when a link opens another app, closing the reader and reporting "finished".
    static func debugSimulateSystemClose() {
        guard let coordinator = current, let safari = coordinator.safari else { return }
        safari.dismiss(animated: false)
        coordinator.safariViewControllerDidFinish(safari)
    }
    #endif

    // MARK: Handoff

    private func watchForReturn() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                Self.log.debug("app resigned active")
                if self?.awayAt == nil { self?.awayAt = Date() }
            }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.becameActive() }
        })
    }

    private func becameActive() {
        guard !finished else { return }
        guard let awayAt else {
            debugNote("back, but never saw Pressed leave")
            return
        }
        self.awayAt = nil
        let away = Date().timeIntervalSince(awayAt)
        debugNote("back after \(Int(away))s away, reader \(readerClosed ? "was closed" : "still open")")
        Self.log.debug("became active after \(away, format: .fixed(precision: 1))s away, readerClosed=\(self.readerClosed)")
        if Self.returnedFromHandoff(handoffAllowed: handoffAllowed, awaySeconds: away) {
            finish()
            showPressSheetOnceReaderIsGone()
        } else if readerClosed {
            // The reader is already gone and the trip was too short to count.
            finish()
            if announcedNoRead { ReaderCoordinator.current = nil } else { concludeWithoutRead() }
        }
    }

    /// Closes the reader if it is still up, then shows the press sheet. After a handoff the reader's remote view can
    /// fail to report that it has gone, so don't wait for that forever: show the sheet after a moment regardless.
    private func showPressSheetOnceReaderIsGone() {
        var shown = false
        let show = { [self] in
            guard !shown else { return }
            shown = true
            showPressSheet()
        }
        if let safari, safari.presentingViewController != nil {
            safari.dismiss(animated: true) { show() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { show() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { show() }
        }
    }

    private func finish() {
        finished = true
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
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
        guard !finished else { return }
        let seconds = Date().timeIntervalSince(openedAt)
        Self.log.debug("reader finished after \(seconds, format: .fixed(precision: 1))s, loaded=\(self.didLoad), away=\(self.awayAt != nil)")
        debugNote("reader closed after \(Int(seconds))s, page loaded: \(didLoad)")
        if Self.countsAsRead(loaded: didLoad, seconds: seconds, handoffAllowed: handoffAllowed) {
            finish()
            // Give Safari's dismissal a moment to finish before presenting the sheet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [self] in showPressSheet() }
            return
        }
        guard handoffAllowed else {
            finish()
            concludeWithoutRead()
            return
        }
        // The link may have opened another app and iOS closed the reader for it. Wait for the user to come back.
        // If the app doesn't go away, this looks like a plain Done: say so after a moment, but keep listening in case
        // the switch is just slow, and give up after a few minutes.
        readerClosed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
            guard !finished, awayAt == nil else { return }
            concludeWithoutRead(keepWatching: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [self] in
            guard !finished else { return }
            finish()
            ReaderCoordinator.current = nil
        }
    }

    /// The visit didn't count as reading: leave the card on the pile, and offer the way out if the lock is the cause.
    private func concludeWithoutRead(keepWatching: Bool = false) {
        announcedNoRead = true
        if !keepWatching { ReaderCoordinator.current = nil }
        guard let presenter else { return }
        if FocusController.isLockedNow, let record = CardStore.shared.fetchRecord(id: cardID), record.status == .pending {
            // Likely stuck: the link wants an app that Focus mode is locking. Offer the way out.
            Self.offerBypass(for: record, from: presenter)
        } else {
            Toast.show("Still on your pile", in: presenter.view)
        }
    }

    private func showPressSheet() {
        ReaderCoordinator.current = nil
        guard let presenter,
              let record = CardStore.shared.fetchRecord(id: cardID),
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
        // If something is still on screen (a reader that didn't close), show the sheet over the top of it.
        var host: UIViewController = presenter
        while let next = host.presentedViewController, !next.isBeingDismissed { host = next }
        host.present(press, animated: true)
    }
}
