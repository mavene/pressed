import UIKit

extension CardKind {
    /// Colour of the underside of a card as it rolls up.
    var cardBackColor: UIColor {
        switch self {
        case .video: return UIColor(hex: 0x1F1B18)
        case .podcast: return UIColor(hex: 0x1A1816)
        default: return UIColor(hex: 0xD9C592)
        }
    }
}

/// A card cut into strips that roll up from the right edge; `setProgress` runs from 0 (flat) to 1 (rolled).
final class PaperRollView: UIView {
    private struct Strip {
        let front: CALayer
        let back: CALayer
        let shade: CALayer
    }

    private var strips: [Strip] = []
    private let pageHeight: CGFloat
    private let pageWidth: CGFloat
    private let innerRadius: CGFloat = 12
    /// How much thicker the scroll gets with each full turn.
    private let thickness: CGFloat = 2.5

    init(image: UIImage, backColor: UIColor, stripCount: Int = 40) {
        pageHeight = image.size.height
        pageWidth = image.size.width
        super.init(frame: CGRect(origin: .zero, size: image.size))
        isUserInteractionEnabled = false
        isAccessibilityElement = false

        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 520
        layer.sublayerTransform = perspective

        let stripWidth = pageWidth / CGFloat(stripCount)
        for index in 0..<stripCount {
            let size = CGSize(width: stripWidth + 0.6, height: pageHeight)

            let back = CALayer()
            back.bounds = CGRect(origin: .zero, size: size)
            back.backgroundColor = backColor.cgColor
            back.isDoubleSided = false

            let front = CALayer()
            front.bounds = CGRect(origin: .zero, size: size)
            front.contents = image.cgImage
            front.contentsScale = image.scale
            front.contentsRect = CGRect(x: CGFloat(index) / CGFloat(stripCount), y: 0,
                                        width: 1 / CGFloat(stripCount), height: 1)
            front.isDoubleSided = false

            let shade = CALayer()
            shade.frame = front.bounds
            shade.backgroundColor = UIColor.black.cgColor
            shade.opacity = 0
            front.addSublayer(shade)

            layer.addSublayer(back)
            layer.addSublayer(front)
            strips.append(Strip(front: front, back: back, shade: shade))
        }
        setProgress(0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setProgress(_ progress: CGFloat) {
        let rolled = max(0, min(1, progress)) * pageWidth
        let rollLine = pageWidth - rolled
        let count = CGFloat(strips.count)
        let stripWidth = pageWidth / count
        let r0 = innerRadius
        let k = thickness / (2 * .pi)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, strip) in strips.enumerated() {
            let fromRight = pageWidth - (CGFloat(index) + 0.5) * stripWidth
            var x = (CGFloat(index) + 0.5) * stripWidth
            var z: CGFloat = 0
            var theta: CGFloat = 0

            if fromRight < rolled {
                // Arc length u past the roll line becomes an angle on a slowly widening spiral.
                let u = rolled - fromRight
                theta = (-r0 + sqrt(r0 * r0 + 2 * k * u)) / k
                let r = r0 + k * theta
                x = rollLine + r * sin(theta)
                z = r0 - r * cos(theta)
            }

            let position = CGPoint(x: x, y: pageHeight / 2)
            strip.front.position = position
            strip.front.zPosition = z
            strip.front.transform = CATransform3DMakeRotation(-theta, 0, 1, 0)
            strip.back.position = position
            strip.back.zPosition = z
            strip.back.transform = CATransform3DMakeRotation(-theta + .pi, 0, 1, 0)
            strip.shade.opacity = Float(min(0.5, 0.42 * abs(sin(theta))))
        }
        CATransaction.commit()
    }
}
