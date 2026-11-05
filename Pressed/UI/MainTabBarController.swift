import UIKit

final class MainTabBarController: UITabBarController {
    let pile = PileViewController()
    let shelf = ShelfViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.desk

        let pileNav = PaperNavigationController(rootViewController: pile)
        pileNav.tabBarItem = UITabBarItem(
            title: "The Pile",
            image: UIImage(systemName: "rectangle.stack"),
            selectedImage: UIImage(systemName: "rectangle.stack.fill"))

        let shelfNav = PaperNavigationController(rootViewController: shelf)
        shelfNav.tabBarItem = UITabBarItem(
            title: "The Shelf",
            image: UIImage(systemName: "bookmark"),
            selectedImage: UIImage(systemName: "bookmark.fill"))

        viewControllers = [pileNav, shelfNav]

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.tabBar
        appearance.shadowColor = Theme.hairline
        let layouts = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        for layout in layouts {
            layout.normal.iconColor = Theme.inkQuiet
            layout.normal.titleTextAttributes = [.foregroundColor: Theme.inkQuiet]
            layout.selected.iconColor = Theme.ink
            layout.selected.titleTextAttributes = [.foregroundColor: Theme.ink]
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentOnboardingIfNeeded()
        pile.presentFarewellIfNeeded()
        AppRouter.shared.flush()
    }

    private func presentOnboardingIfNeeded() {
        guard !AppSettings.hasOnboarded, presentedViewController == nil else { return }
        let onboarding = OnboardingViewController()
        onboarding.modalPresentationStyle = .fullScreen
        onboarding.onFinish = { [weak self] in
            AppSettings.hasOnboarded = true
            self?.dismiss(animated: true) {
                self?.pile.presentFarewellIfNeeded()
                AppRouter.shared.flush()
            }
        }
        present(onboarding, animated: false)
    }
}
