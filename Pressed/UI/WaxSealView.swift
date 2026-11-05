import UIKit

/// Colours for a wax seal. The finish decides the look.
struct SealStyle {
    let fill: UIColor
    let ring: UIColor
    let letter: UIColor
    let dashedRing: Bool
    let drips: Bool

    static func style(for finish: CardFinish) -> SealStyle {
        switch finish {
        case .none:
            return SealStyle(fill: UIColor(hex: 0x9E2F24), ring: UIColor(hex: 0x6E1E16),
                             letter: UIColor(hex: 0xF1D3C8), dashedRing: false, drips: false)
        case .fresh:
            return SealStyle(fill: UIColor(hex: 0xB8862B), ring: UIColor(hex: 0x8A6418),
                             letter: UIColor(hex: 0xFFF3D6), dashedRing: false, drips: false)
        case .closeCall:
            return SealStyle(fill: UIColor(hex: 0x9E2F24), ring: UIColor(hex: 0x6E1E16),
                             letter: UIColor(hex: 0xF1D3C8), dashedRing: false, drips: true)
        case .longRead:
            return SealStyle(fill: UIColor(hex: 0x6B4A2B), ring: UIColor(hex: 0x45301B),
                             letter: UIColor(hex: 0xE9D7B8), dashedRing: false, drips: false)
        case .rescued:
            return SealStyle(fill: UIColor(hex: 0x2F6F6A), ring: UIColor(hex: 0x1D4744),
                             letter: UIColor(hex: 0xD6EFEA), dashedRing: true, drips: false)
        }
    }
}

/// A scalloped wax seal with a letter P. Each one sits at a slightly different angle.
final class WaxSealView: UIView {
    private let drip = CAShapeLayer()
    private let body = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let letterLabel = UILabel()

    private var style = SealStyle.style(for: .none)
    private var restingTransform = CGAffineTransform.identity

    var showsLetter: Bool = true {
        didSet { letterLabel.isHidden = !showsLetter }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        isUserInteractionEnabled = false
        layer.addSublayer(drip)
        layer.addSublayer(body)
        layer.addSublayer(ring)
        body.shadowColor = UIColor.black.cgColor
        body.shadowOpacity = 0.28
        body.shadowRadius = 2
        body.shadowOffset = CGSize(width: 0, height: 2)
        ring.fillColor = UIColor.clear.cgColor
        letterLabel.text = "P"
        letterLabel.textAlignment = .center
        letterLabel.isAccessibilityElement = false
        addSubview(letterLabel)
        applyStyle()
    }

    convenience init(showsLetter: Bool) {
        self.init(frame: .zero)
        self.showsLetter = showsLetter
        letterLabel.isHidden = !showsLetter
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(finish: CardFinish, seed: Int32) {
        style = SealStyle.style(for: finish)
        let angle = CGFloat((Int(seed) % 29) - 14) * .pi / 180
        restingTransform = CGAffineTransform(rotationAngle: angle)
        transform = restingTransform
        applyStyle()
        setNeedsLayout()
    }

    private func applyStyle() {
        body.fillColor = style.fill.cgColor
        drip.fillColor = style.fill.cgColor
        drip.isHidden = !style.drips
        ring.strokeColor = style.ring.cgColor
        ring.lineDashPattern = style.dashedRing ? [3, 2.5] : nil
        letterLabel.textColor = style.letter
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0 else { return }
        let r = diameter / 2
        let c = CGPoint(x: bounds.midX, y: bounds.midY)

        let scallops = UIBezierPath(arcCenter: c, radius: r * 0.75, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        for k in 0..<12 {
            let angle = CGFloat(k) * (.pi * 2 / 12)
            let center = CGPoint(x: c.x + cos(angle) * r * 0.78, y: c.y + sin(angle) * r * 0.78)
            scallops.append(UIBezierPath(arcCenter: center, radius: r * 0.17,
                                         startAngle: 0, endAngle: .pi * 2, clockwise: true))
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body.frame = bounds
        body.path = scallops.cgPath
        ring.frame = bounds
        ring.path = UIBezierPath(arcCenter: c, radius: r * 0.53, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        ring.lineWidth = max(1, r * 0.05)
        drip.frame = bounds
        drip.path = UIBezierPath(
            roundedRect: CGRect(x: c.x - r * 0.15, y: c.y + r * 0.45, width: r * 0.3, height: r * 0.7),
            cornerRadius: r * 0.15).cgPath
        CATransaction.commit()

        letterLabel.frame = bounds
        letterLabel.font = Theme.serif(r * 0.62, .bold, scaled: false)
    }

    /// The seal lands with a thump.
    func drop(completion: (() -> Void)? = nil) {
        isHidden = false
        guard !UIAccessibility.isReduceMotionEnabled else {
            alpha = 1
            transform = restingTransform
            completion?()
            return
        }
        alpha = 0
        transform = restingTransform.scaledBy(x: 1.7, y: 1.7).rotated(by: -0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            Haptics.thunk()
        }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.55,
                       initialSpringVelocity: 0.6, options: [], animations: {
            self.alpha = 1
            self.transform = self.restingTransform
        }, completion: { _ in
            completion?()
        })
    }
}
