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
            makePage(illustration: makeCurlIllustration(),
                     title: "Links you save curl up if you ignore them.",
                     body: "Share a link to Pressed from any app. It lands on your Pile and slowly curls as its due date gets closer."),
            makePage(illustration: makePressIllustration(),
                     title: "Read one and press it flat to keep it forever.",
                     body: "When you finish reading, press the card. It becomes a bookmark with a wax seal, hanging on The Shelf."),
            makePage(illustration: makeCrumbleIllustration(),
                     title: "Ignore it for a week and it crumbles. No guilt.",
                     body: "Nothing piles up for ever. To save a link, tap Share in any app and choose Pressed. You may need to tap More the first time.")
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

    // MARK: Illustrations

    /// A blank paper card with placeholder bars and a stamp.
    private func makeMiniCard(level: Int, stamp: String, tilt: CGFloat) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        let paper = PaperCardView()
        paper.level = level
        paper.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(paper)

        let image = UIView()
        image.backgroundColor = level == 0 ? UIColor(hex: 0xA9BCC4) : UIColor(hex: 0xB9AE97)
        image.layer.cornerRadius = 4
        let barOne = UIView()
        barOne.backgroundColor = UIColor(hex: 0xD9CFBD)
        barOne.layer.cornerRadius = 5
        let barTwo = UIView()
        barTwo.backgroundColor = UIColor(hex: 0xD9CFBD)
        barTwo.layer.cornerRadius = 5
        let stampLabel = PaddedLabel()
        stampLabel.text = stamp
        stampLabel.font = Theme.mono(11, .bold, scaled: false)
        stampLabel.textColor = Theme.stampRed
        stampLabel.layer.borderColor = Theme.stampRed.cgColor
        stampLabel.layer.borderWidth = 1.5
        stampLabel.layer.cornerRadius = 3

        let stack = UIStackView(arrangedSubviews: [image, barOne, barTwo, stampLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 190),
            paper.topAnchor.constraint(equalTo: card.topAnchor),
            paper.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            paper.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            paper.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            image.widthAnchor.constraint(equalTo: stack.widthAnchor),
            image.heightAnchor.constraint(equalToConstant: 66),
            barOne.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.85),
            barOne.heightAnchor.constraint(equalToConstant: 10),
            barTwo.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.6),
            barTwo.heightAnchor.constraint(equalToConstant: 10)
        ])

        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 600
        transform = CATransform3DRotate(transform, CGFloat(level) * 4 * .pi / 180, 1, 0, 0)
        transform = CATransform3DRotate(transform, tilt * .pi / 180, 0, 0, 1)
        card.layer.transform = transform
        card.isAccessibilityElement = false
        return card
    }

    private func makeCurlIllustration() -> UIView {
        let container = UIView()
        let flat = makeMiniCard(level: 0, stamp: "DUE IN 7 DAYS", tilt: -6)
        let curled = makeMiniCard(level: 3, stamp: "DUE TOMORROW", tilt: 6)
        container.addSubview(flat)
        container.addSubview(curled)
        NSLayoutConstraint.activate([
            flat.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            flat.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            curled.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            curled.topAnchor.constraint(equalTo: container.topAnchor, constant: 90)
        ])
        container.isAccessibilityElement = true
        container.accessibilityLabel = "A flat card next to a curled, yellowed card"
        return container
    }

    private func makePressIllustration() -> UIView {
        let container = UIView()
        let card = makeMiniCard(level: 0, stamp: "PRESSED", tilt: -3)
        let seal = WaxSealView(frame: .zero)
        seal.configure(finish: .fresh, seed: 7)
        seal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        container.addSubview(seal)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 50),
            seal.widthAnchor.constraint(equalToConstant: 92),
            seal.heightAnchor.constraint(equalToConstant: 92),
            seal.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: 24),
            seal.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: 28)
        ])
        container.isAccessibilityElement = true
        container.accessibilityLabel = "A card with a gold wax seal"
        return container
    }

    private func makeCrumbleIllustration() -> UIView {
        let container = UIView()
        let card = makeMiniCard(level: 3, stamp: "DUE TODAY", tilt: 3)
        container.addSubview(card)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 30)
        ])
        let flakes: [(CGFloat, CGFloat, CGFloat)] = [
            (-70, 215, 7), (-30, 235, 5), (20, 222, 8), (60, 245, 5), (90, 228, 6), (-5, 255, 4)
        ]
        for (dx, y, size) in flakes {
            let flake = UIView()
            flake.backgroundColor = UIColor(hex: 0xE9D7A6)
            flake.layer.cornerRadius = 1
            flake.transform = CGAffineTransform(rotationAngle: dx / 40)
            flake.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(flake)
            NSLayoutConstraint.activate([
                flake.widthAnchor.constraint(equalToConstant: size),
                flake.heightAnchor.constraint(equalToConstant: size),
                flake.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: dx),
                flake.topAnchor.constraint(equalTo: container.topAnchor, constant: y)
            ])
        }
        container.isAccessibilityElement = true
        container.accessibilityLabel = "A yellowed card turning into flakes of paper"
        return container
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
