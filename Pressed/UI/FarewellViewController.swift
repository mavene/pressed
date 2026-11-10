import UIKit

/// Shown on next launch after links expire: a bin for one link, a fireplace for several.
final class FarewellViewController: UIViewController {
    /// Called once the burning is over, so the caller can mark the cards as crumbled.
    var onBurned: (() -> Void)?

    private let records: [CardRecord]
    private let scene: FarewellSceneView
    private let captionLabel = UILabel()
    private let detailLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private var started = false

    init(records: [CardRecord]) {
        self.records = records
        if records.count == 1, let only = records.first {
            scene = SoloBinView(record: only)
        } else {
            scene = FireplaceView(records: records)
        }
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: 0x1B1612, alpha: 0.93)

        scene.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scene)

        captionLabel.font = Theme.serif(26, .semibold, style: .title2)
        captionLabel.textColor = Theme.paper0
        captionLabel.textAlignment = .center
        captionLabel.numberOfLines = 0
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.accessibilityTraits = .header

        detailLabel.font = Theme.mono(13, .regular, style: .footnote)
        detailLabel.textColor = UIColor(hex: 0xEDE5D6, alpha: 0.7)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 2
        detailLabel.adjustsFontForContentSizeCategory = true

        var config = UIButton.Configuration.filled()
        config.title = records.count == 1 ? "Rest in pieces" : "Warm enough"
        config.baseBackgroundColor = Theme.paper0
        config.baseForegroundColor = Theme.ink
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 28, bottom: 14, trailing: 28)
        doneButton.configuration = config
        doneButton.alpha = 0
        doneButton.isUserInteractionEnabled = false
        doneButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)

        let stack = PassThroughStackView(arrangedSubviews: [captionLabel, detailLabel, doneButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.setCustomSpacing(22, after: detailLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            scene.topAnchor.constraint(equalTo: view.topAnchor),
            scene.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scene.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scene.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        scene.play(say: { [weak self] text in
            self?.setCaption(text)
        }, finished: { [weak self] in
            self?.finish()
        })
    }

    private func setCaption(_ text: String) {
        UIView.transition(with: captionLabel, duration: 0.2, options: .transitionCrossDissolve) {
            self.captionLabel.text = text
        }
    }

    /// The punchline under "Returned to the internet." A gentle dig at never having read it.
    private static let soloShames = [
        "You said you\u{2019}d read it.",
        "It waited a whole week. Rude.",
        "Saved with the best of intentions.",
        "Unread, but not unloved. Okay, unloved.",
        "Maybe next time. (There won\u{2019}t be.)"
    ]

    private func shame() -> String {
        let n = records.count
        if n == 1 { return Self.soloShames.randomElement() ?? "" }
        return [
            "\(n) links saved. \(n) links read: zero.",
            "\(n) good intentions, now ash.",
            "Saved \(n), read none. Bold strategy.",
            "You\u{2019}ll definitely read the next \(n)."
        ].randomElement() ?? ""
    }

    private func finish() {
        detailLabel.text = shame()
        setCaption("Returned to the internet.")
        UIAccessibility.post(notification: .announcement, argument: "\(captionLabel.text ?? "") \(detailLabel.text ?? "")")
        onBurned?()
        onBurned = nil
        doneButton.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.35) {
            self.doneButton.alpha = 1
        }
    }
}

/// A stack that only catches touches on its own buttons.
private final class PassThroughStackView: UIStackView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
