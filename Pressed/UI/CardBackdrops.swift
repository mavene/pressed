import UIKit

// Card faces for videos and podcasts; other kinds use PaperCardView.

/// Text colours and extra top room a card needs, depending on its face.
struct CardPalette {
    let title: UIColor
    let soft: UIColor
    let stamp: UIColor
    /// Room above the content, e.g. for a clapperboard's clapstick.
    let topInset: CGFloat
}

extension CardKind {
    /// True when the card is drawn by a `KindBackdropView` instead of plain paper.
    var hasCustomCard: Bool { self == .video || self == .podcast }

    var cardPalette: CardPalette {
        switch self {
        case .video:
            return CardPalette(title: UIColor(hex: 0xF3ECDD), soft: UIColor(hex: 0xC9BFAE),
                               stamp: UIColor(hex: 0xFF8A73), topInset: ClapperboardBackdrop.stickBand)
        case .podcast:
            return CardPalette(title: UIColor(hex: 0xF3ECDD), soft: UIColor(hex: 0xBDB4A6),
                               stamp: UIColor(hex: 0xFF9C80), topInset: 0)
        default:
            return CardPalette(title: Theme.ink, soft: Theme.inkSoft, stamp: Theme.stampRed, topInset: 0)
        }
    }
}

/// Small deterministic generator so a given card always wears its wear the same way.
struct BackdropRandom {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(truncatingIfNeeded: seed) &* 2862933555777941757 &+ 3037000493
    }

    /// 0...1
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
}

/// Base for a card face. `level` is the curl level (0 fresh ... 3 about to go).
class KindBackdropView: UIView {
    var level: Int = 0 {
        didSet { if level != oldValue { setNeedsLayout() } }
    }
    var seed: Int32 = 0 {
        didSet { if seed != oldValue { setNeedsLayout() } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var clampedLevel: Int { max(0, min(3, level)) }
}

// MARK: - Clapperboard (video)

/// A film clapperboard whose clapstick opens and edges crumble as the due date nears.
final class ClapperboardBackdrop: KindBackdropView {
    static let stickBand: CGFloat = 22
    private static let stickHeight: CGFloat = 20
    private static let bodyHex: [UInt32] = [0x25211D, 0x2B2622, 0x322C26, 0x3A332B]
    /// How far the free end of the clapstick lifts, in points.
    private static let lift: [CGFloat] = [0, 3, 7, 11]
    private static let stripeAlpha: [CGFloat] = [1, 0.95, 0.85, 0.7]
    private static let chalkAlpha: [CGFloat] = [0.14, 0.12, 0.09, 0.06]
    private static let bites = [0, 1, 3, 7]
    private static let spots: [CGPoint] = [
        CGPoint(x: 1.0, y: 0.12), CGPoint(x: 0.0, y: 0.7), CGPoint(x: 0.55, y: 1.0), CGPoint(x: 1.0, y: 0.62),
        CGPoint(x: 0.15, y: 1.0), CGPoint(x: 0.0, y: 0.2), CGPoint(x: 0.85, y: 1.0)
    ]

    private let shadowLayer = CALayer()
    private let body = CALayer()
    private let bodyMask = CAShapeLayer()
    private let chalk = CAShapeLayer()
    private let cracks = CAShapeLayer()
    private let debris = CAShapeLayer()
    private let stick = CALayer()
    private let stripes = CAShapeLayer()
    private let hinge = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shadowLayer.shadowColor = UIColor(hex: 0x462F14).cgColor
        shadowLayer.shadowOpacity = 0.3
        shadowLayer.shadowRadius = 6
        shadowLayer.shadowOffset = CGSize(width: 0, height: 5)

        body.mask = bodyMask
        bodyMask.fillRule = .evenOdd

        chalk.fillColor = UIColor.clear.cgColor
        chalk.lineWidth = 1
        cracks.fillColor = UIColor.clear.cgColor
        cracks.strokeColor = UIColor(hex: 0xF3ECDD, alpha: 0.22).cgColor
        cracks.lineWidth = 0.8
        cracks.lineJoin = .round
        debris.fillColor = UIColor(hex: 0x3A332B).cgColor

        stick.backgroundColor = UIColor(hex: 0x15110F).cgColor
        stick.cornerRadius = 3
        stick.masksToBounds = true
        stick.anchorPoint = CGPoint(x: 0, y: 1)
        stripes.fillColor = UIColor(hex: 0xF3ECDD).cgColor
        stick.addSublayer(stripes)

        hinge.backgroundColor = UIColor(hex: 0x8A8176).cgColor
        hinge.cornerRadius = 3.5

        [shadowLayer, body, chalk, cracks, debris, stick, hinge].forEach { layer.addSublayer($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > Self.stickBand else { return }
        let l = clampedLevel
        let band = Self.stickBand
        let bodyRect = CGRect(x: 0, y: band, width: w, height: h - band)
        let local = CGRect(origin: .zero, size: bodyRect.size)
        let bodyColor = UIColor(hex: Self.bodyHex[l]).cgColor

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        shadowLayer.frame = bodyRect
        shadowLayer.backgroundColor = bodyColor
        shadowLayer.shadowPath = UIBezierPath(roundedRect: local, cornerRadius: 4).cgPath

        body.frame = bodyRect
        body.backgroundColor = bodyColor
        bodyMask.frame = local
        bodyMask.path = bodyPath(in: local, level: l)

        chalk.frame = bodyRect
        chalk.strokeColor = UIColor(hex: 0xF3ECDD, alpha: Self.chalkAlpha[l]).cgColor
        let chalkPath = UIBezierPath(roundedRect: local.insetBy(dx: 6, dy: 6), cornerRadius: 2)
        chalkPath.move(to: CGPoint(x: 6, y: local.height * 0.42))
        chalkPath.addLine(to: CGPoint(x: local.width - 6, y: local.height * 0.42))
        chalk.path = chalkPath.cgPath

        cracks.frame = bodyRect
        cracks.isHidden = l < 2
        cracks.path = l < 2 ? nil : crackPath(in: local, level: l)

        debris.frame = bounds
        debris.isHidden = l < 2
        debris.path = l < 2 ? nil : debrisPath(level: l)

        // Clapstick, hinged at its left end and swinging open.
        let stickHeight = Self.stickHeight
        stick.bounds = CGRect(x: 0, y: 0, width: w, height: stickHeight)
        stick.position = CGPoint(x: 0, y: band - 1)
        let angle = asin(min(1, Self.lift[l] / w))
        stick.transform = CATransform3DMakeRotation(-angle, 0, 0, 1)
        stripes.frame = stick.bounds
        stripes.opacity = Float(Self.stripeAlpha[l])
        let stripePath = UIBezierPath()
        var x: CGFloat = -10
        while x < w + 10 {
            stripePath.move(to: CGPoint(x: x, y: stickHeight))
            stripePath.addLine(to: CGPoint(x: x + 13, y: stickHeight))
            stripePath.addLine(to: CGPoint(x: x + 23, y: 0))
            stripePath.addLine(to: CGPoint(x: x + 10, y: 0))
            stripePath.close()
            x += 28
        }
        stripes.path = stripePath.cgPath

        hinge.frame = CGRect(x: 3, y: band - 5, width: 7, height: 7)

        CATransaction.commit()
    }

    /// The board outline with bites taken out of its edges (even-odd fill).
    private func bodyPath(in rect: CGRect, level l: Int) -> CGPath {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        var rng = BackdropRandom(seed: Int(seed))
        let offset = Int(seed.magnitude)
        for i in 0..<Self.bites[l] {
            let spot = Self.spots[(i + offset) % Self.spots.count]
            let center = CGPoint(x: spot.x * rect.width, y: spot.y * rect.height)
            let size = CGFloat(5 + l * 2) + rng.next() * 4
            let start = rng.next() * 2 * .pi
            let bite = UIBezierPath()
            for corner in 0..<3 {
                let angle = start + CGFloat(corner) * 2.1
                let radius = size * (0.7 + 0.5 * rng.next())
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if corner == 0 { bite.move(to: point) } else { bite.addLine(to: point) }
            }
            bite.close()
            path.append(bite)
        }
        return path.cgPath
    }

    private func crackPath(in rect: CGRect, level l: Int) -> CGPath {
        let w = rect.width
        let h = rect.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: w * 0.72, y: 0))
        path.addLine(to: CGPoint(x: w * 0.69, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.3))
        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.48))
        if l == 3 {
            path.move(to: CGPoint(x: 0, y: h * 0.6))
            path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.55))
            path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.66))
            path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.62))
            path.move(to: CGPoint(x: w * 0.69, y: h * 0.18))
            path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.22))
        }
        return path.cgPath
    }

    /// Crumbs that have fallen off the bottom edge.
    private func debrisPath(level l: Int) -> CGPath {
        var rng = BackdropRandom(seed: Int(seed) &+ 99)
        let path = UIBezierPath()
        for _ in 0..<(l == 2 ? 2 : 5) {
            let size = 3 + rng.next() * 2.5
            let x = bounds.width * (0.08 + 0.84 * rng.next())
            path.append(UIBezierPath(rect: CGRect(x: x, y: bounds.height + 1 + rng.next() * 4, width: size, height: size)))
        }
        return path.cgPath
    }
}

// MARK: - Vinyl (podcast)

/// A record. The thumbnail sits on the label; scratches pile up and the shine dulls as the due date nears.
final class VinylBackdrop: KindBackdropView {
    private static let labelHex: [UInt32] = [0xB8C9D1, 0xD69A5C, 0xC9B08A, 0x9BB89A, 0xC77D6B]
    private static let sheenOpacity: [Float] = [1, 0.8, 0.6, 0.35]
    private static let scratches = [0, 3, 8, 15]
    /// Matches the thumbnail on the card (64pt square at 14, 14).
    private static let center = CGPoint(x: 46, y: 46)

    private let shadowLayer = CALayer()
    private let disc = CALayer()
    private let grooves = CAShapeLayer()
    private let sheen = CAGradientLayer()
    private let labelRing = CAShapeLayer()
    private let scratchLayer = CAShapeLayer()
    private let deepLayer = CAShapeLayer()
    private let dust = CAShapeLayer()
    private let dull = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shadowLayer.shadowColor = UIColor(hex: 0x462F14).cgColor
        shadowLayer.shadowOpacity = 0.3
        shadowLayer.shadowRadius = 6
        shadowLayer.shadowOffset = CGSize(width: 0, height: 5)

        disc.backgroundColor = UIColor(hex: 0x131110).cgColor
        disc.cornerRadius = 10
        disc.masksToBounds = true

        grooves.fillColor = UIColor.clear.cgColor
        grooves.strokeColor = UIColor(hex: 0x2C2926).cgColor
        grooves.lineWidth = 0.6

        sheen.type = .conic
        sheen.colors = [
            UIColor.clear, UIColor(white: 1, alpha: 0.13), UIColor.clear, UIColor.clear,
            UIColor(white: 1, alpha: 0.09), UIColor.clear, UIColor.clear
        ].map(\.cgColor)
        sheen.locations = [0, 0.05, 0.10, 0.5, 0.55, 0.6, 1]

        scratchLayer.fillColor = UIColor.clear.cgColor
        scratchLayer.strokeColor = UIColor(white: 1, alpha: 0.28).cgColor
        scratchLayer.lineWidth = 0.6
        deepLayer.fillColor = UIColor.clear.cgColor
        deepLayer.strokeColor = UIColor(white: 1, alpha: 0.5).cgColor
        deepLayer.lineWidth = 1.2
        deepLayer.lineCap = .round
        dust.fillColor = UIColor(hex: 0x9A9387, alpha: 0.55).cgColor
        dull.backgroundColor = UIColor(hex: 0x8A8379).cgColor

        [grooves, sheen, labelRing, scratchLayer, deepLayer, dust, dull].forEach { disc.addSublayer($0) }
        layer.addSublayer(shadowLayer)
        layer.addSublayer(disc)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = CGRect(origin: .zero, size: bounds.size)
        guard rect.width > 0, rect.height > 0 else { return }
        let l = clampedLevel
        let c = Self.center

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        shadowLayer.frame = rect
        shadowLayer.shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: 10).cgPath
        disc.frame = rect

        grooves.frame = rect
        let ringPath = UIBezierPath()
        let maxR = hypot(max(c.x, rect.width - c.x), max(c.y, rect.height - c.y))
        var r: CGFloat = 42
        var ring = 0
        while r < maxR {
            // Every ninth ring is skipped: the smooth gap between tracks.
            if ring % 9 != 8 {
                ringPath.append(UIBezierPath(arcCenter: c, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: true))
            }
            r += 3.2
            ring += 1
        }
        grooves.path = ringPath.cgPath

        sheen.frame = rect
        sheen.startPoint = CGPoint(x: c.x / rect.width, y: c.y / rect.height)
        sheen.endPoint = CGPoint(x: c.x / rect.width, y: 0)
        sheen.opacity = Self.sheenOpacity[l]

        labelRing.frame = rect
        let labelColor = Self.labelHex[Int(seed.magnitude) % Self.labelHex.count]
        labelRing.fillColor = UIColor(hex: labelColor).cgColor
        labelRing.strokeColor = UIColor(hex: 0x000000, alpha: 0.6).cgColor
        labelRing.lineWidth = 1.5
        labelRing.path = UIBezierPath(arcCenter: c, radius: 37, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath

        scratchLayer.frame = rect
        scratchLayer.path = scratchPath(in: rect, count: Self.scratches[l], seedOffset: 0)
        deepLayer.frame = rect
        deepLayer.isHidden = l < 3
        deepLayer.path = l < 3 ? nil : deepPath(in: rect)
        dust.frame = rect
        dust.isHidden = l < 2
        dust.path = l < 2 ? nil : dustPath(in: rect, count: l == 2 ? 5 : 12)

        dull.frame = rect
        dull.opacity = [0, 0, 0.06, 0.13][l]

        CATransaction.commit()
    }

    private func scratchPath(in rect: CGRect, count: Int, seedOffset: Int) -> CGPath {
        var rng = BackdropRandom(seed: Int(seed) &+ seedOffset)
        let path = UIBezierPath()
        for _ in 0..<count {
            let start = CGPoint(x: rng.next() * rect.width, y: rng.next() * rect.height)
            let angle = rng.next() * 2 * .pi
            let length = (0.15 + rng.next() * 0.45) * rect.width
            let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            let bend = (rng.next() - 0.5) * 24
            let control = CGPoint(x: (start.x + end.x) / 2 + bend, y: (start.y + end.y) / 2 - bend)
            path.move(to: start)
            path.addQuadCurve(to: end, controlPoint: control)
        }
        return path.cgPath
    }

    /// Two long gouges that run right across the record.
    private func deepPath(in rect: CGRect) -> CGPath {
        var rng = BackdropRandom(seed: Int(seed) &+ 41)
        let path = UIBezierPath()
        for _ in 0..<2 {
            let x = rect.width * (0.35 + 0.5 * rng.next())
            path.move(to: CGPoint(x: x, y: -2))
            path.addQuadCurve(to: CGPoint(x: x + (rng.next() - 0.5) * 50, y: rect.height + 2),
                              controlPoint: CGPoint(x: x + (rng.next() - 0.5) * 30, y: rect.height * 0.5))
        }
        return path.cgPath
    }

    private func dustPath(in rect: CGRect, count: Int) -> CGPath {
        var rng = BackdropRandom(seed: Int(seed) &+ 7)
        let path = UIBezierPath()
        for _ in 0..<count {
            let size = 1 + rng.next() * 1.6
            path.append(UIBezierPath(ovalIn: CGRect(x: rng.next() * rect.width, y: rng.next() * rect.height,
                                                     width: size, height: size)))
        }
        return path.cgPath
    }
}
