import UIKit

// Small reusable views.

/// A label with padding. Used for the rubber-stamp "DUE" labels and toasts.
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7) {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}

final class PaddedTextField: UITextField {
    var insets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: insets) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: insets) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: insets) }
}

/// The square picture on a card. Falls back to a coloured block with the kind's symbol.
final class ThumbnailView: UIView {
    private let imageView = UIImageView()
    private let symbolView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 4
        clipsToBounds = true
        isAccessibilityElement = false

        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.contentMode = .center
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        addSubview(symbolView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(image: UIImage?, kind: CardKind) {
        backgroundColor = kind.blockColor
        imageView.image = image
        imageView.isHidden = image == nil
        symbolView.isHidden = image != nil
        symbolView.image = UIImage(
            systemName: kind.symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular))
        symbolView.tintColor = kind.blockSymbolColor
    }
}

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for record: CardRecord) -> UIImage? {
        guard let data = record.imageData else { return nil }
        let key = "\(record.id.uuidString)-\(data.count)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A short message at the bottom of the screen.
enum Toast {
    @MainActor
    static func show(_ text: String, in view: UIView) {
        let label = PaddedLabel()
        label.insets = UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)
        label.text = text
        label.font = Theme.sans(15, .semibold, style: .subheadline)
        label.textColor = Theme.paper0
        label.backgroundColor = Theme.ink
        label.textAlignment = .center
        label.layer.cornerRadius = 22
        label.clipsToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
        UIAccessibility.post(notification: .announcement, argument: text)
        UIView.animate(withDuration: 0.25, animations: {
            label.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.2, options: [], animations: {
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        })
    }
}

/// Round outlined button used in headers.
@MainActor
func makeCircleButton(symbol: String, label: String) -> UIButton {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(
        systemName: symbol,
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
    config.baseForegroundColor = Theme.ink
    let button = UIButton(configuration: config)
    button.layer.cornerRadius = 22
    button.layer.borderWidth = 1
    button.layer.borderColor = Theme.outline.cgColor
    button.accessibilityLabel = label
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        button.widthAnchor.constraint(equalToConstant: 44),
        button.heightAnchor.constraint(equalToConstant: 44)
    ])
    return button
}

/// Navigation controller with no system bar that keeps swipe-back.
final class PaperNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
