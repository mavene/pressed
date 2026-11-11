import UIKit

/// A sheet of paper that curls as its due date nears (level 0 flat, level 3 yellowed and folded).
final class PaperCardView: UIView {
    private static let paperHex: [UInt32] = [0xFBF8F1, 0xF7EFDB, 0xF1E4C2, 0xE9D7A6]
    static let foldHex: [UInt32] = [0xFBF8F1, 0xE2D3AE, 0xD9C592, 0xCDB57A]
    static let cuts: [CGFloat] = [0, 14, 26, 38]
    private static let shadowRadius: [CGFloat] = [3, 5, 8, 12]
    private static let shadowOffsetY: [CGFloat] = [2, 4, 6, 9]
    private static let shadowOpacity: [Float] = [0.14, 0.18, 0.22, 0.28]
    private static let shadeAlpha: [CGFloat] = [0, 0.06, 0.12, 0.2]

    private let paperLayer = CAShapeLayer()
    private let shadeLayer = CAGradientLayer()
    private let shadeMask = CAShapeLayer()
    private let creaseLayer = CAShapeLayer()
    private let foldLayer = CAShapeLayer()

    var level: Int = 0 {
        didSet { setNeedsLayout() }
    }

    /// Videos and podcasts swap the paper for their own face (clapperboard, record).
    var kind: CardKind = .article {
        didSet {
            guard kind != oldValue else { return }
            backdrop?.removeFromSuperview()
            backdrop = nil
            switch kind {
            case .video: backdrop = ClapperboardBackdrop()
            case .podcast: backdrop = VinylBackdrop()
            default: break
            }
            if let backdrop { addSubview(backdrop) }
            setNeedsLayout()
        }
    }

    var seed: Int32 = 0 {
        didSet { setNeedsLayout() }
    }

    private var backdrop: KindBackdropView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.addSublayer(paperLayer)
        shadeLayer.mask = shadeMask
        layer.addSublayer(shadeLayer)
        layer.addSublayer(creaseLayer)
        layer.addSublayer(foldLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    static func paperPath(in rect: CGRect, cut: CGFloat, radius: CGFloat = 6) -> UIBezierPath {
        let r = radius
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        if cut > 0 {
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(withCenter: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                        startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(withCenter: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                    startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(withCenter: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                    startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(withCenter: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                    startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        path.close()
        return path
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = CGRect(origin: .zero, size: bounds.size)
        guard rect.width > 0, rect.height > 0 else { return }
        let l = max(0, min(3, level))

        let custom = backdrop != nil
        [paperLayer, shadeLayer, creaseLayer, foldLayer].forEach { $0.isHidden = custom }
        if let backdrop {
            backdrop.frame = rect
            backdrop.seed = seed
            backdrop.level = l
            return
        }
        paperLayer.isHidden = false
        let cut = Self.cuts[l]
        let path = Self.paperPath(in: rect, cut: cut).cgPath

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        paperLayer.frame = rect
        paperLayer.path = path
        paperLayer.fillColor = UIColor(hex: Self.paperHex[l]).cgColor
        paperLayer.shadowColor = UIColor(hex: 0x462F14).cgColor
        paperLayer.shadowOpacity = Self.shadowOpacity[l]
        paperLayer.shadowRadius = Self.shadowRadius[l]
        paperLayer.shadowOffset = CGSize(width: 0, height: Self.shadowOffsetY[l])
        paperLayer.shadowPath = path

        let shade = Self.shadeAlpha[l]
        shadeLayer.frame = rect
        shadeMask.frame = rect
        shadeMask.path = path
        shadeLayer.colors = [UIColor.clear.cgColor, UIColor(hex: 0x78551E, alpha: shade).cgColor]
        shadeLayer.startPoint = CGPoint(x: 0.5, y: 0.55)
        shadeLayer.endPoint = CGPoint(x: 0.5, y: 1)
        shadeLayer.isHidden = shade == 0

        foldLayer.isHidden = cut == 0
        if cut > 0 {
            let fold = UIBezierPath()
            fold.move(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            fold.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            fold.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY + cut))
            fold.close()
            foldLayer.frame = rect
            foldLayer.path = fold.cgPath
            foldLayer.fillColor = UIColor(hex: Self.foldHex[l]).cgColor
            foldLayer.strokeColor = UIColor(hex: 0x5A4119, alpha: 0.3).cgColor
            foldLayer.lineWidth = 1
        }

        creaseLayer.isHidden = l < 3
        if l == 3 {
            let crease = UIBezierPath()
            crease.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.9))
            crease.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.22))
            crease.move(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.95))
            crease.addLine(to: CGPoint(x: rect.width * 0.86, y: rect.height * 0.5))
            creaseLayer.frame = rect
            creaseLayer.path = crease.cgPath
            creaseLayer.strokeColor = UIColor(hex: 0x6E501E, alpha: 0.16).cgColor
            creaseLayer.fillColor = UIColor.clear.cgColor
            creaseLayer.lineWidth = 1
        }

        CATransaction.commit()
    }
}
