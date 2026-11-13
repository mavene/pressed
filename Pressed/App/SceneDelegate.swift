import UIKit
import UserNotifications

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var root: MainTabBarController?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.ink
        let root = MainTabBarController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        self.root = root

        AppRouter.shared.attach(root)
        NudgeCoordinator.shared.start()
        FocusCoordinator.shared.start()
        #if DEBUG
        DebugScreenshots.run(root: root)
        #endif

        if let url = connectionOptions.urlContexts.first?.url {
            AppRouter.shared.handle(url: url)
        }
        if let response = connectionOptions.notificationResponse {
            AppRouter.shared.handleNotification(userInfo: response.notification.request.content.userInfo)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        root?.pile.refreshFromSystem()
        AppRouter.shared.flush()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        BackgroundRefresh.schedule()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            AppRouter.shared.handle(url: url)
        }
    }
}
