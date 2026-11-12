import UIKit

/// Three swipeable cards on first launch: curl, press, crumble.
final class OnboardingViewController: UIViewController, UIScrollViewDelegate {
    var onFinish: (() -> Void)?

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let nextButton = UIButton(type: .system)
    private var pages: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.desk

        let brand = UILabel()
        brand.text = "Pressed"
        brand.font = Theme.serif(22, .semibold, style: .title3)
        brand.textColor = Theme.ink
        brand.adjustsFontForContentSizeCategory = true

        var skipConfig = UIButton.Configuration.plain()
        skipConfig.title = "Skip"
        skipConfig.baseForegroundColor = Theme.inkQuiet
        let skip = UIButton(configuration: skipConfig)
        skip.addAction(UIAction { [weak self] _ in self?.finish() }, for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [brand, UIView(), skip])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topRow)

        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        pages = [
            makePage(illustration: OnboardingIllustrations.curl(),
                     title: "Read it or lose it.",
                     body: "Links you save curl up as their deadline closes in. Tap Share, pick Pressed (tap More the first time), and it lands on your Pile."),
            makePage(illustration: OnboardingIllustrations.press(),
                     title: "Read one and press it flat to keep it forever.",
                     body: "When you finish reading, press the card. It becomes a bookmark with a wax seal, hanging on The Shelf."),
            makePage(illustration: OnboardingIllustrations.crumble(),
                     title: "Wait too long and it's toast.",
                     body: "Nothing lasts for ever. Not even your reading list. Anything you haven't read within 3, 7 or 14 days crumbles away. No pressure. (Some.)")
        ]
        let pageStack = UIStackView(arrangedSubviews: pages)
        pageStack.axis = .horizontal
        pageStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(pageStack)

        pageControl.numberOfPages = pages.count
        pageControl.currentPageIndicatorTintColor = Theme.ink
        pageControl.pageIndicatorTintColor = Theme.outline
        pageControl.isUserInteractionEnabled = false

        var nextConfig = UIButton.Configuration.filled()
        nextConfig.title = "Next"
        nextConfig.baseBackgroundColor = Theme.ink
        nextConfig.baseForegroundColor = Theme.paper0
        nextConfig.cornerStyle = .capsule
        nextConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 36, bottom: 16, trailing: 36)
        nextButton.configuration = nextConfig
        nextButton.addAction(UIAction { [weak self] _ in self?.advance() }, for: .touchUpInside)

        let bottomRow = UIStackView(arrangedSubviews: [pageControl, UIView(), nextButton])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomRow)

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            topRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomRow.topAnchor, constant: -12),

            pageStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pageStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pageStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pageStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pageStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            bottomRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            bottomRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            bottomRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        for page in pages {
            page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        }
    }

    // MARK: Paging

    private var currentPage: Int {
        let width = max(scrollView.bounds.width, 1)
        return max(0, min(pages.count - 1, Int(round(scrollView.contentOffset.x / width))))
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = currentPage
        pageControl.currentPage = page
        var config = nextButton.configuration
        config?.title = page == pages.count - 1 ? "Get started" : "Next"
        nextButton.configuration = config
    }

    private func advance() {
        let page = currentPage
        if page >= pages.count - 1 {
            finish()
        } else {
            let x = scrollView.bounds.width * CGFloat(page + 1)
            scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
        }
    }

    private func finish() {
        onFinish?()
    }

    // MARK: Pages

    private func makePage(illustration: UIView, title: String, body: String) -> UIView {
        let page = UIView()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.serif(31, .semibold, style: .largeTitle)
        titleLabel.textColor = Theme.ink
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = Theme.sans(16, .regular, style: .body)
        bodyLabel.textColor = Theme.inkSoft
        bodyLabel.numberOfLines = 0
        bodyLabel.adjustsFontForContentSizeCategory = true

        illustration.translatesAutoresizingMaskIntoConstraints = false
        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = 14
        textStack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(illustration)
        page.addSubview(textStack)
        NSLayoutConstraint.activate([
            illustration.topAnchor.constraint(equalTo: page.topAnchor, constant: 16),
            illustration.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 28),
            illustration.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -28),
            illustration.heightAnchor.constraint(equalToConstant: 280),
            textStack.topAnchor.constraint(equalTo: illustration.bottomAnchor, constant: 24),
            textStack.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 28),
            textStack.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -28)
        ])
        return page
    }
}

// MARK: - How to save

/// Steps for adding Pressed to the Share sheet. Used from the empty Pile and from Settings.
final class HowToSaveViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }

        let title = UILabel()
        title.text = "Saving a link"
        title.font = Theme.serif(26, .semibold, style: .title2)
        title.textColor = Theme.ink
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header

        let steps = [
            "In Safari or any app, tap the Share button.",
            "Look for Pressed in the row of apps. The first time, tap More and switch Pressed on.",
            "Tap Pressed. The link lands on your Pile and starts to curl."
        ]
        let stack = UIStackView(arrangedSubviews: [title] + steps.enumerated().map { index, text in
            makeStep(number: index + 1, text: text)
        })
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])
    }

    private func makeStep(number: Int, text: String) -> UIView {
        let badge = UILabel()
        badge.text = "\(number)"
        badge.font = Theme.mono(14, .bold, style: .subheadline)
        badge.textColor = Theme.paper0
        badge.textAlignment = .center
        badge.backgroundColor = Theme.ink
        badge.layer.cornerRadius = 14
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 28),
            badge.heightAnchor.constraint(equalToConstant: 28)
        ])
        badge.isAccessibilityElement = false

        let label = UILabel()
        label.text = text
        label.font = Theme.sans(16, .regular, style: .body)
        label.textColor = Theme.ink
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [badge, label])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 14
        return row
    }
}
