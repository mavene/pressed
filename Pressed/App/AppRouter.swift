import UIKit

/// Turns notification taps and `pressed://` links into screens (`stack`, `card/<uuid>`).
@MainActor
final class AppRouter {
    static let shared = AppRouter()

    enum Route {
        case stack
        case card(UUID)
    }

    private weak var root: MainTabBarController?
    private var pending: Route?

    func attach(_ root: MainTabBarController) {
        self.root = root
    }

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "pressed" else { return }
        switch url.host?.lowercased() {
        case "stack":
            go(.stack)
        case "card":
            if let id = UUID(uuidString: url.lastPathComponent) { go(.card(id)) }
        default:
            break
        }
    }

    func handleNotification(userInfo: [AnyHashable: Any]) {
        if (userInfo["route"] as? String) == "stack" { go(.stack) }
    }

    func go(_ route: Route) {
        pending = route
        flush()
    }

    /// Opens the queued route as soon as the root screen is on screen and nothing else is covering it.
    func flush() {
        guard let root, root.viewIfLoaded?.window != nil, let route = pending else { return }
        guard root.presentedViewController == nil else {
            // Something (onboarding, the reader) is in the way. Try again shortly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.flush() }
            return
        }
        pending = nil
        switch route {
        case .stack:
            let stack = StackViewController()
            stack.modalPresentationStyle = .fullScreen
            root.present(stack, animated: true)
        case .card(let id):
            guard let record = CardStore.shared.fetchRecord(id: id), record.status == .pending else { return }
            root.selectedIndex = 0
            ReaderCoordinator.open(record, from: root.pile)
        }
    }
}
