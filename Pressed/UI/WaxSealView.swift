import UIKit

/// Colours for a wax seal. The finish decides the look.
struct SealStyle {
    let fill: UIColor
    let ring: UIColor
    let letter: UIColor
    let dashedRing: Bool
    let melt: Melt

    /// How much the wax has run. Close calls keep a single drip; rescued seals are a full splotchy melt.
    enum Melt { case none, drip, splotchy }

    /// Every finish uses the same red wax for now, so seals look consistent. The finish still decides the shape:
    /// close calls drip, and rescued cards are a splotchy melt with a dashed ring, like wax that nearly ran away.
    /// Per-finish colours can come back once they pay off.
    static func style(for finish: CardFinish) -> SealStyle {
        let melt: Melt = finish == .closeCall ? .drip : (finish == .rescued ? .splotchy : .none)
        return SealStyle(fill: UIColor(hex: 0x9E2F24), ring: UIColor(hex: 0x6E1E16),
                         letter: UIColor(hex: 0xF1D3C8),
                         dashedRing: finish == .rescued, melt: melt)
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
        drip.isHidden = style.melt == .none
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

        let bodyPath: UIBezierPath
        if style.melt == .splotchy {
            bodyPath = splotchyBody(center: c, radius: r)
        } else {
            bodyPath = UIBezierPath(arcCenter: c, radius: r * 0.75, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            for k in 0..<12 {
                let angle = CGFloat(k) * (.pi * 2 / 12)
                let center = CGPoint(x: c.x + cos(angle) * r * 0.78, y: c.y + sin(angle) * r * 0.78)
                bodyPath.append(UIBezierPath(arcCenter: center, radius: r * 0.17,
                                             startAngle: 0, endAngle: .pi * 2, clockwise: true))
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body.frame = bounds
        body.path = bodyPath.cgPath
        ring.frame = bounds
        ring.path = UIBezierPath(arcCenter: c, radius: r * 0.53, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        ring.lineWidth = max(1, r * 0.05)
        drip.frame = bounds
        drip.path = (style.melt == .splotchy ? splotchyDrips(center: c, radius: r) : closeCallDrips(center: c, radius: r)).cgPath
        CATransaction.commit()

        letterLabel.frame = bounds
        letterLabel.font = Theme.serif(r * 0.62, .bold, scaled: false)
    }

    /// The close-call drip: three drips of different lengths, each ending in a round bulb.
    private func closeCallDrips(center c: CGPoint, radius r: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let specs: [(x: CGFloat, width: CGFloat, bottom: CGFloat)] = [
            (0.06, 0.28, 1.45),   // long middle drip
            (-0.40, 0.20, 1.12),  // shorter on the left
            (0.46, 0.17, 0.98)    // shortest on the right
        ]
        for spec in specs {
            let w = r * spec.width
            let top = c.y + r * 0.5
            let bottom = c.y + r * spec.bottom
            let bulb = w * 0.72
            let x = c.x + r * spec.x
            path.append(UIBezierPath(roundedRect: CGRect(x: x - w / 2, y: top, width: w, height: bottom - bulb - top),
                                     cornerRadius: w / 2))
            path.append(UIBezierPath(arcCenter: CGPoint(x: x, y: bottom - bulb), radius: bulb,
                                     startAngle: 0, endAngle: .pi * 2, clockwise: true))
        }
        return path
    }

    /// A lumpy, uneven blob instead of a neat scalloped circle, so the seal looks half melted.
    private func splotchyBody(center c: CGPoint, radius r: CGFloat) -> UIBezierPath {
        let blob = UIBezierPath()
        let steps = 96
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps) * .pi * 2
            let wobble = 0.05 * sin(3 * t + 1.0) + 0.045 * sin(5 * t + 2.2) + 0.03 * sin(9 * t + 0.4)
            let radius = r * (0.70 + wobble)
            let point = CGPoint(x: c.x + cos(t) * radius, y: c.y + sin(t) * radius)
            if i == 0 { blob.move(to: point) } else { blob.addLine(to: point) }
        }
        blob.close()
        // Splotches of wax that pooled around the edge.
        let splotches: [(angle: CGFloat, dist: CGFloat, size: CGFloat)] = [
            (0.3, 0.78, 0.15), (1.2, 0.80, 0.11), (2.0, 0.76, 0.17), (2.9, 0.82, 0.10),
            (3.8, 0.77, 0.14), (4.6, 0.81, 0.12), (5.5, 0.79, 0.16)
        ]
        for splotch in splotches {
            let center = CGPoint(x: c.x + cos(splotch.angle) * r * splotch.dist,
                                 y: c.y + sin(splotch.angle) * r * splotch.dist)
            blob.append(UIBezierPath(arcCenter: center, radius: r * splotch.size,
                                     startAngle: 0, endAngle: .pi * 2, clockwise: true))
        }
        return blob
    }

    /// Uneven drips with round bulbs, plus loose droplets that have already fallen away.
    private func splotchyDrips(center c: CGPoint, radius r: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let drips: [(x: CGFloat, width: CGFloat, bottom: CGFloat)] = [
            (0.06, 0.28, 1.45), (-0.40, 0.20, 1.12), (0.46, 0.17, 0.98), (-0.12, 0.12, 1.20)
        ]
        for spec in drips {
            let w = r * spec.width
            let top = c.y + r * 0.5
            let bottom = c.y + r * spec.bottom
            let bulb = w * 0.72
            let x = c.x + r * spec.x
            path.append(UIBezierPath(roundedRect: CGRect(x: x - w / 2, y: top, width: w, height: bottom - bulb - top),
                                     cornerRadius: w / 2))
            path.append(UIBezierPath(arcCenter: CGPoint(x: x, y: bottom - bulb), radius: bulb,
                                     startAngle: 0, endAngle: .pi * 2, clockwise: true))
        }
        let droplets: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [(0.30, 1.30, 0.07), (-0.62, 0.92, 0.06), (0.74, 0.50, 0.06)]
        for d in droplets {
            path.append(UIBezierPath(arcCenter: CGPoint(x: c.x + r * d.x, y: c.y + r * d.y), radius: r * d.size,
                                     startAngle: 0, endAngle: .pi * 2, clockwise: true))
        }
        return path
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
