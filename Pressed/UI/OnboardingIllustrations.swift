import UIKit

/// The three pictures on the onboarding pages: a flat card beside a curled one, a pressed card hanging from a shelf,
/// and a card burning to ash.
@MainActor
enum OnboardingIllustrations {
    static func curl() -> UIView {
        let container = UIView()
        let flat = MiniCardView(level: 0, stamp: "DUE IN 7 DAYS", tilt: -6)
        let curled = MiniCardView(level: 3, stamp: "DUE TOMORROW", tilt: 6)
        // The curled card overlaps the flat one. Its 3D tilt pushes its upper half behind the flat card's plane
        // (about 18 points at most), so lift it clear of that.
        flat.layer.zPosition = 0
        curled.layer.zPosition = 60
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

    static func press() -> UIView {
        let container = UIView()
        let shelf = ShelfPlankView()
        let hanging = HangingCardView(stamp: "PRESSED")
        container.addSubview(hanging)
        container.addSubview(shelf)
        NSLayoutConstraint.activate([
            shelf.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            shelf.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            shelf.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hanging.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            hanging.topAnchor.constraint(equalTo: shelf.bottomAnchor, constant: -4)
        ])
        container.isAccessibilityElement = true
        container.accessibilityLabel = "A card with a gold wax seal, hanging from a shelf"
        return container
    }

    static func crumble() -> UIView {
        let view = BurningCardView(card: MiniCardView(level: 3, stamp: "DUE TODAY", tilt: 3))
        view.isAccessibilityElement = true
        view.accessibilityLabel = "A yellowed card catching fire and falling away as ash"
        return view
    }
}

// MARK: - The card

/// A blank paper card with placeholder bars and a stamp.
final class MiniCardView: UIView {
    static let width: CGFloat = 190
    private static let inset: CGFloat = 14

    private let foldLayer = CAShapeLayer()
    private let cut: CGFloat
    private let level: Int

    init(level: Int, stamp: String, tilt: CGFloat) {
        let level = max(0, min(3, level))
        self.level = level
        self.cut = PaperCardView.cuts[level]
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false

        let paper = PaperCardView()
        paper.level = level
        paper.translatesAutoresizingMaskIntoConstraints = false
        addSubview(paper)

        // The picture stops at the paper's torn corner: `cut - 2 * inset` is where the fold's diagonal crosses it.
        let image = NotchedView(notch: max(0, cut - 2 * Self.inset))
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
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            paper.topAnchor.constraint(equalTo: topAnchor),
            paper.bottomAnchor.constraint(equalTo: bottomAnchor),
            paper.leadingAnchor.constraint(equalTo: leadingAnchor),
            paper.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.inset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.inset),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset),
            image.widthAnchor.constraint(equalTo: stack.widthAnchor),
            image.heightAnchor.constraint(equalToConstant: 66),
            barOne.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.85),
            barOne.heightAnchor.constraint(equalToConstant: 10),
            barTwo.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.6),
            barTwo.heightAnchor.constraint(equalToConstant: 10)
        ])

        // The folded corner goes on top of the picture, like a real flap of paper.
        foldLayer.fillColor = UIColor(hex: PaperCardView.foldHex[level]).cgColor
        foldLayer.strokeColor = UIColor(hex: 0x5A4119, alpha: 0.3).cgColor
        foldLayer.lineWidth = 1
        foldLayer.isHidden = cut == 0
        layer.addSublayer(foldLayer)

        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 600
        transform = CATransform3DRotate(transform, CGFloat(level) * 4 * .pi / 180, 1, 0, 0)
        transform = CATransform3DRotate(transform, tilt * .pi / 180, 0, 0, 1)
        layer.transform = transform
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard cut > 0 else { return }
        let fold = UIBezierPath()
        fold.move(to: CGPoint(x: bounds.maxX - cut, y: 0))
        fold.addLine(to: CGPoint(x: bounds.maxX, y: cut))
        fold.addLine(to: CGPoint(x: bounds.maxX - cut, y: cut))
        fold.close()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        foldLayer.frame = bounds
        foldLayer.path = fold.cgPath
        CATransaction.commit()
    }
}

/// A rectangle with its top-right corner sliced off at 45 degrees.
private final class NotchedView: UIView {
    private let notch: CGFloat
    private let clip = CAShapeLayer()

    init(notch: CGFloat) {
        self.notch = notch
        super.init(frame: .zero)
        if notch > 0 { layer.mask = clip }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard notch > 0 else { return }
        let path = UIBezierPath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: bounds.maxX - notch, y: 0))
        path.addLine(to: CGPoint(x: bounds.maxX, y: notch))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: 0, y: bounds.maxY))
        path.close()
        clip.frame = bounds
        clip.path = path.cgPath
    }
}

// MARK: - Page 2: hanging from a shelf

/// A wooden plank with a few books standing on it.
private final class ShelfPlankView: UIView {
    private static let bookHeight: CGFloat = 30
    private static let plankHeight: CGFloat = 16

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.bookHeight + Self.plankHeight).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let plankTop = Self.bookHeight

        func block(_ rect: CGRect, _ hex: UInt32, radius: CGFloat = 1) {
            let l = CALayer()
            l.frame = rect
            l.backgroundColor = UIColor(hex: hex).cgColor
            l.cornerRadius = radius
            layer.addSublayer(l)
        }

        // (distance from the near end, width, height, colour). Mirrored onto the other end.
        let books: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (6, 12, 28, 0x8E2A20), (19, 10, 24, 0x2F6F6A), (30, 13, 29, 0xC9A45A), (44, 9, 22, 0x3B4A6B)
        ]
        for (offset, w, h, hex) in books {
            block(CGRect(x: offset, y: plankTop - h, width: w, height: h), hex)
            block(CGRect(x: bounds.width - offset - w, y: plankTop - h, width: w, height: h), hex)
        }
        block(CGRect(x: 0, y: plankTop, width: bounds.width, height: Self.plankHeight), 0x8B6A47, radius: 2)
        block(CGRect(x: 0, y: plankTop + Self.plankHeight - 5, width: bounds.width, height: 5), 0x4A3322, radius: 2)
    }
}

/// The pressed card and its wax seal, hung from a hook by a cord and swinging gently.
private final class HangingCardView: UIView {
    private static let cordLength: CGFloat = 36
    private let cord = CAShapeLayer()
    private let pins = CAShapeLayer()

    init(stamp: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let card = MiniCardView(level: 0, stamp: stamp, tilt: 0)
        let seal = WaxSealView(frame: .zero)
        seal.configure(finish: .fresh, seed: 7)
        seal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        addSubview(seal)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: Self.cordLength),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            seal.widthAnchor.constraint(equalToConstant: 92),
            seal.heightAnchor.constraint(equalToConstant: 92),
            seal.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: 24),
            seal.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: 28)
        ])

        cord.strokeColor = UIColor(hex: 0x6B4E2E).cgColor
        cord.fillColor = UIColor.clear.cgColor
        cord.lineWidth = 1.5
        pins.fillColor = UIColor(hex: 0xC9A45A).cgColor
        pins.strokeColor = UIColor(hex: 0x6B4E2E).cgColor
        pins.lineWidth = 1
        layer.addSublayer(cord)
        layer.addSublayer(pins)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let top = CGPoint(x: bounds.midX, y: 0)
        let left = CGPoint(x: 24, y: Self.cordLength + 7)
        let right = CGPoint(x: bounds.maxX - 24, y: Self.cordLength + 7)
        let lines = UIBezierPath()
        lines.move(to: left)
        lines.addLine(to: top)
        lines.addLine(to: right)
        let dots = UIBezierPath()
        for point in [top, left, right] {
            dots.append(UIBezierPath(arcCenter: point, radius: 3, startAngle: 0, endAngle: 2 * .pi, clockwise: true))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cord.path = lines.cgPath
        pins.path = dots.cgPath
        CATransaction.commit()
        if bounds.height != swingHeight { startSwinging() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        startSwinging()
    }

    private var swingHeight: CGFloat = 0

    /// Rotation about the hook at the top centre. (Moving the layer's anchor point would make Auto Layout
    /// misplace the view, so the pivot is built into the transform instead.)
    private func swung(by angle: CGFloat) -> CATransform3D {
        let half = bounds.height / 2
        var t = CATransform3DMakeTranslation(0, half, 0)
        t = CATransform3DConcat(t, CATransform3DMakeRotation(angle, 0, 0, 1))
        return CATransform3DConcat(t, CATransform3DMakeTranslation(0, -half, 0))
    }

    private func startSwinging() {
        guard bounds.height > 0, window != nil else { return }
        swingHeight = bounds.height
        layer.removeAnimation(forKey: "swing")
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let swing = CABasicAnimation(keyPath: "transform")
        swing.fromValue = NSValue(caTransform3D: swung(by: -0.07))
        swing.toValue = NSValue(caTransform3D: swung(by: 0.07))
        swing.duration = 1.7
        swing.autoreverses = true
        swing.repeatCount = .infinity
        swing.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(swing, forKey: "swing")
    }
}

// MARK: - Page 3: burning to ash

/// A card that catches fire, burns from the bottom up with flames along the edge of the char, drops ash and embers,
/// then fades out and starts again. With Reduce Motion on it is a still picture of a half-burnt card.
private final class BurningCardView: UIView {
    private static let loop: CFTimeInterval = 5.5
    /// Share of the loop spent burning; the rest is the card fading out and a short pause.
    private static let burnShare = 0.7
    private static let steps = 24

    private let card: MiniCardView
    private let emitter = CAEmitterLayer()
    private var builtSize = CGSize.zero
    private var effectLayers: [CALayer] = []

    init(card: MiniCardView) {
        self.card = card
        super.init(frame: .zero)
        addSubview(card)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.topAnchor.constraint(equalTo: topAnchor, constant: 30)
        ])
        layer.addSublayer(emitter)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = card.bounds.size
        guard size.width > 0, size != builtSize else { return }
        builtSize = size
        effectLayers.forEach { $0.removeFromSuperlayer() }
        effectLayers = []
        build(size)
    }

    /// Where the ember line is, as a share of the card height measured from the bottom.
    private func front(_ progress: CGFloat) -> CGFloat { -0.1 + progress * 1.2 }

    private func locations(_ progress: CGFloat) -> [NSNumber] {
        let f = front(progress)
        func stop(_ v: CGFloat) -> NSNumber { NSNumber(value: Double(min(1, max(0, v)))) }
        return [stop(0), stop(f - 0.06), stop(f), stop(f + 0.04), stop(f + 0.09)]
    }

    private func build(_ size: CGSize) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let w = size.width, h = size.height
        let n = Self.steps
        let burnEnd = Self.burnShare
        // Paper catches slowly and then goes: the same smoothstep the farewell burn uses.
        let progress: [CGFloat] = (0...n).map { k in
            let t = CGFloat(k) / CGFloat(n)
            return t * t * (3 - 2 * t)
        }
        let keyTimes: [NSNumber] = (0...n).map { NSNumber(value: Double($0) / Double(n) * burnEnd) } + [1]

        func keyframes(_ keyPath: String, _ values: [Any]) -> CAKeyframeAnimation {
            let a = CAKeyframeAnimation(keyPath: keyPath)
            a.values = values + [values.last as Any]
            a.keyTimes = keyTimes
            a.duration = Self.loop
            a.repeatCount = .infinity
            a.calculationMode = .linear
            return a
        }
        func fade(_ keyPath: String, _ stops: [(Double, Double)]) -> CAKeyframeAnimation {
            let a = CAKeyframeAnimation(keyPath: keyPath)
            a.keyTimes = stops.map { NSNumber(value: $0.0) }
            a.values = stops.map { NSNumber(value: $0.1) }
            a.duration = Self.loop
            a.repeatCount = .infinity
            return a
        }

        // Char and glowing ember line, clipped to the card's outline.
        let burn = CAGradientLayer()
        burn.frame = card.bounds
        burn.colors = [
            UIColor(hex: 0x3A332C).cgColor, UIColor(hex: 0x1F1A16).cgColor, UIColor(hex: 0xE2551C).cgColor,
            UIColor(hex: 0xFFC247, alpha: 0.85).cgColor, UIColor(hex: 0xFFC247, alpha: 0).cgColor
        ]
        burn.startPoint = CGPoint(x: 0.5, y: 1)
        burn.endPoint = CGPoint(x: 0.5, y: 0)
        let outline = CAShapeLayer()
        outline.path = PaperCardView.paperPath(in: card.bounds, cut: PaperCardView.cuts[3]).cgPath
        burn.mask = outline
        card.layer.addSublayer(burn)
        effectLayers.append(burn)

        // Flames ride along the ember line.
        let fireLine = CALayer()
        fireLine.bounds = CGRect(x: 0, y: 0, width: w, height: 0)
        func lineY(_ p: CGFloat) -> CGFloat { h * (1 - front(p)) }
        fireLine.position = CGPoint(x: w / 2, y: lineY(reduceMotion ? 0.55 : 0))
        card.layer.addSublayer(fireLine)
        effectLayers.append(fireLine)

        let flames: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.14, 15, 22, 0.21), (0.36, 24, 34, 0.17), (0.6, 22, 30, 0.26), (0.84, 16, 24, 0.19)
        ]
        for (xShare, fw, fh, period) in flames {
            let outer = CAShapeLayer()
            outer.bounds = CGRect(x: 0, y: 0, width: fw, height: fh)
            outer.anchorPoint = CGPoint(x: 0.5, y: 1)
            outer.position = CGPoint(x: w * xShare, y: 5)
            outer.path = FarewellSprite.flamePath(width: fw, height: fh)
            outer.fillColor = UIColor(hex: 0xE2551C).cgColor
            let inner = CAShapeLayer()
            inner.bounds = CGRect(x: 0, y: 0, width: fw * 0.5, height: fh * 0.6)
            inner.anchorPoint = CGPoint(x: 0.5, y: 1)
            inner.position = CGPoint(x: fw / 2, y: fh - 1)
            inner.path = FarewellSprite.flamePath(width: fw * 0.5, height: fh * 0.6)
            inner.fillColor = UIColor(hex: 0xFFC247).cgColor
            outer.addSublayer(inner)
            fireLine.addSublayer(outer)
            if !reduceMotion {
                let flicker = CABasicAnimation(keyPath: "transform.scale.y")
                flicker.fromValue = 0.8
                flicker.toValue = 1.15
                flicker.duration = period
                flicker.autoreverses = true
                flicker.repeatCount = .infinity
                flicker.timeOffset = Double.random(in: 0..<period)
                outer.add(flicker, forKey: "flicker")
            }
        }

        if reduceMotion {
            burn.locations = locations(0.55)
            emitter.birthRate = 0
            return
        }

        burn.locations = locations(0)
        burn.add(keyframes("locations", progress.map { locations($0) }), forKey: "burn")
        fireLine.add(keyframes("position.y", progress.map { lineY($0) }), forKey: "rise")
        fireLine.opacity = 0
        fireLine.add(fade("opacity", [(0, 0), (0.05, 1), (burnEnd - 0.08, 1), (burnEnd, 0), (1, 0)]), forKey: "show")
        // The whole card, char and all, fades away once it has burnt, then comes back for the next round.
        card.layer.add(fade("opacity", [(0, 0), (0.05, 1), (burnEnd, 1), (burnEnd + 0.14, 0), (1, 0)]), forKey: "loop")

        // Ash and embers fall from just below the ember line.
        emitter.frame = CGRect(x: card.center.x - w / 2, y: card.center.y - h / 2, width: w, height: h)
        emitter.emitterShape = .rectangle
        emitter.emitterSize = CGSize(width: w * 0.9, height: 30)
        emitter.renderMode = .unordered
        emitter.emitterPosition = CGPoint(x: w / 2, y: min(h, lineY(0) + 15))
        emitter.emitterCells = [
            ashCell(hex: 0x4A433B, rate: 22), ashCell(hex: 0x8A7F70, rate: 12), emberCell()
        ]
        emitter.birthRate = 0
        let positions = progress.map { NSValue(cgPoint: CGPoint(x: w / 2, y: min(h, lineY($0) + 15))) }
        emitter.add(keyframes("emitterPosition", positions), forKey: "follow")
        emitter.add(fade("birthRate", [(0, 0), (0.08, 1), (burnEnd, 1.5), (burnEnd + 0.08, 0), (1, 0)]), forKey: "rate")
    }

    private func ashCell(hex: UInt32, rate: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = FarewellSprite.dot(6)
        cell.color = UIColor(hex: hex).cgColor
        cell.birthRate = rate
        cell.lifetime = 1.9
        cell.lifetimeRange = 0.6
        cell.velocity = 10
        cell.velocityRange = 10
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi
        cell.yAcceleration = 34
        cell.scale = 0.7
        cell.scaleRange = 0.4
        cell.alphaSpeed = -0.4
        return cell
    }

    private func emberCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = FarewellSprite.dot(6)
        cell.color = UIColor(hex: 0xFF8A2B).cgColor
        cell.birthRate = 9
        cell.lifetime = 0.9
        cell.lifetimeRange = 0.3
        cell.velocity = 20
        cell.velocityRange = 10
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 3
        cell.yAcceleration = -8
        cell.scale = 0.5
        cell.scaleRange = 0.3
        cell.alphaSpeed = -1.0
        return cell
    }
}
