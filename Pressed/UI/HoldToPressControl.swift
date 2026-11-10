import UIKit

/// A dark pill you hold down until it fills. Sends `.primaryActionTriggered` when it completes.
/// VoiceOver users double-tap instead, because holding is not possible for everyone.
final class HoldToPressControl: UIControl {
    private let progressView = UIView()
    private let titleLabel = UILabel()
    private var progressWidth: NSLayoutConstraint!
    private var animator: UIViewPropertyAnimator?
    private let holdDuration: TimeInterval = 0.9
    private(set) var isComplete = false

    var title: String = "Hold to press" {
        didSet { titleLabel.text = title }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.ink
        layer.cornerRadius = 29
        clipsToBounds = true

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Press"
        accessibilityHint = "Presses this link into a bookmark"

        progressView.backgroundColor = UIColor(hex: 0x4A3F33)
        progressView.isUserInteractionEnabled = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        titleLabel.text = title
        titleLabel.font = Theme.sans(17, .semibold, style: .headline)
        titleLabel.textColor = Theme.paper0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isUserInteractionEnabled = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        progressWidth = progressView.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressWidth,
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 58)
        ])

        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        hold.minimumPressDuration = 0
        addGestureRecognizer(hold)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func handleHold(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            begin()
        case .ended, .cancelled, .failed:
            cancel()
        default:
            break
        }
    }

    private func begin() {
        guard !isComplete else { return }
        Haptics.light()
        animator?.stopAnimation(true)
        progressWidth.constant = 0
        layoutIfNeeded()

        let newAnimator = UIViewPropertyAnimator(duration: holdDuration, curve: .linear) { [weak self] in
            guard let self else { return }
            self.progressWidth.constant = self.bounds.width
            self.layoutIfNeeded()
        }
        newAnimator.addCompletion { [weak self] position in
            guard let self, position == .end else { return }
            self.isComplete = true
            self.sendActions(for: .primaryActionTriggered)
        }
        animator = newAnimator
        newAnimator.startAnimation()
    }

    private func cancel() {
        guard !isComplete else { return }
        animator?.stopAnimation(true)
        animator = nil
        UIView.animate(withDuration: 0.2) {
            self.progressWidth.constant = 0
            self.layoutIfNeeded()
        }
    }

    override func accessibilityActivate() -> Bool {
        guard !isComplete else { return true }
        isComplete = true
        sendActions(for: .primaryActionTriggered)
        return true
    }

    /// Lets the control be used again.
    func reset() {
        animator?.stopAnimation(true)
        animator = nil
        isComplete = false
        progressWidth.constant = 0
        setNeedsLayout()
    }
}

#if DEBUG
extension HoldToPressControl {
    /// Debug builds only: runs the real hold animation, as if a finger were held down.
    func debugHold() { begin() }
}
#endif
