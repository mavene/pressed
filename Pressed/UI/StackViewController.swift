import UIKit

/// Tonight's Stack: about three cards chosen by due date, how much time you have, and variety.
final class StackViewController: UIViewController {
    private enum Budget: Int, CaseIterable {
        case any = 0, five = 5, fifteen = 15, thirty = 30

        var title: String {
            switch self {
            case .any: return "Any"
            case .five: return "5 min"
            case .fifteen: return "15 min"
            case .thirty: return "30 min"
            }
        }

        var minutes: Int? { self == .any ? nil : rawValue }
    }

    private let store = CardStore.shared
    private let subtitleLabel = UILabel()
    private let picker = UISegmentedControl(items: Budget.allCases.map(\.title))
    private let cardsStack = UIStackView()
    private let emptyLabel = UILabel()
    private var budget: Budget = .any

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.desk
        build()
        NotificationCenter.default.addObserver(
            self, selector: #selector(cardsChanged), name: .cardsDidChange, object: nil)
        refresh()
    }

    @objc private func cardsChanged() {
        refresh()
    }

    // MARK: Layout

    private func build() {
        let close = makeCircleButton(symbol: "xmark", label: "Close")
        close.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)

        let title = UILabel()
        title.text = "Tonight\u{2019}s stack"
        title.font = Theme.serif(34, .semibold, style: .largeTitle)
        title.textColor = Theme.ink
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header

        subtitleLabel.font = Theme.mono(13, .regular, style: .footnote)
        subtitleLabel.textColor = Theme.inkQuiet
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let timeLabel = UILabel()
        timeLabel.text = "I have\u{2026}"
        timeLabel.font = Theme.sans(14, .semibold, style: .subheadline)
        timeLabel.textColor = Theme.ink
        timeLabel.adjustsFontForContentSizeCategory = true

        picker.selectedSegmentIndex = 0
        picker.selectedSegmentTintColor = Theme.ink
        picker.setTitleTextAttributes([.foregroundColor: Theme.paper0], for: .selected)
        picker.setTitleTextAttributes([.foregroundColor: Theme.ink], for: .normal)
        picker.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.budget = Budget.allCases[self.picker.selectedSegmentIndex]
            self.refresh()
        }, for: .valueChanged)

        cardsStack.axis = .vertical
        cardsStack.spacing = 18

        emptyLabel.text = "Nothing waiting. Go live a little."
        emptyLabel.font = Theme.serif(20, .regular, style: .title3, italic: true)
        emptyLabel.textColor = Theme.inkQuiet
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.isHidden = true

        let content = UIStackView(arrangedSubviews: [title, subtitleLabel, timeLabel, picker, cardsStack, emptyLabel])
        content.axis = .vertical
        content.spacing = 12
        content.setCustomSpacing(4, after: title)
        content.setCustomSpacing(22, after: subtitleLabel)
        content.setCustomSpacing(8, after: timeLabel)
        content.setCustomSpacing(26, after: picker)
        content.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(close)
        view.addSubview(scroll)
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            scroll.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -40),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24)
        ])
    }

    // MARK: Data

    private func refresh() {
        let result = StackPicker.pick(from: store.fetchPending(), budgetMinutes: budget.minutes)

        cardsStack.arrangedSubviews.forEach {
            cardsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for record in result.cards {
            cardsStack.addArrangedSubview(makeCardButton(for: record))
        }

        emptyLabel.isHidden = !result.cards.isEmpty
        picker.isHidden = result.cards.isEmpty && store.fetchPending().isEmpty
        if result.cards.isEmpty {
            subtitleLabel.text = "nothing waiting"
        } else {
            let count = result.cards.count
            subtitleLabel.text = "\(count) card\(count == 1 ? "" : "s") \u{00B7} about \(result.totalMinutes) min"
        }
    }

    private func makeCardButton(for record: CardRecord) -> UIView {
        let button = UIControl()
        let card = CardContentView()
        card.configure(with: record)
        card.isUserInteractionEnabled = false
        card.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: button.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        button.accessibilityLabel = card.spokenSummary
        button.accessibilityHint = "Opens the link"
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            ReaderCoordinator.open(record, from: self)
        }, for: .touchUpInside)
        return button
    }
}
