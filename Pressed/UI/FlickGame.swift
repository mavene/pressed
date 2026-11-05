import UIKit
import UIKit.UIGestureRecognizerSubclass

// The toolkit behind the "throw it away" game.

enum FlickMath {
    static func speed(_ velocity: CGPoint) -> CGFloat {
        hypot(velocity.x, velocity.y)
    }

    /// Slower than this and a release is just letting go, not a throw.
    static let minimumThrowSpeed: CGFloat = 220
}

/// Tracks a finger from touch-down and measures its speed over the last ~100ms.
private final class TouchTracker: UIGestureRecognizer {
    var canStart: ((CGPoint) -> Bool)?
    private(set) var location = CGPoint.zero
    private var samples: [(time: TimeInterval, point: CGPoint)] = []
    private var endTime: TimeInterval = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard samples.isEmpty, touches.count == 1, let touch = touches.first, let view else {
            state = .failed
            return
        }
        let point = touch.location(in: view)
        guard canStart?(point) == true else {
            state = .failed
            return
        }
        location = point
        samples = [(touch.timestamp, point)]
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else { return }
        location = touch.location(in: view)
        samples.append((touch.timestamp, location))
        samples.removeAll { touch.timestamp - $0.time > 0.12 }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        endTime = touches.first?.timestamp ?? endTime
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }

    override func reset() {
        samples = []
    }

    /// Points per second. Zero if the finger had stopped before letting go.
    var releaseVelocity: CGPoint {
        guard let first = samples.first, let last = samples.last, last.time - first.time > 0.012 else { return .zero }
        if endTime - last.time > 0.09 { return .zero }
        let dt = last.time - first.time
        return CGPoint(x: (last.point.x - first.point.x) / dt, y: (last.point.y - first.point.y) / dt)
    }
}

/// Lets a finger pick up any of `candidates` (the last one is on top) and flick it away.
@MainActor
final class FlickRecognizer: NSObject {
    var candidates: [UIView] = []
    /// View, where it was let go, and the finger's velocity in points per second.
    var onRelease: ((UIView, CGPoint, CGPoint) -> Void)?

    private weak var host: UIView?
    private let tracker = TouchTracker()
    private var held: UIView?
    private var offset = CGPoint.zero

    var isEnabled: Bool {
        get { tracker.isEnabled }
        set { tracker.isEnabled = newValue }
    }

    init(host: UIView) {
        self.host = host
        super.init()
        tracker.cancelsTouchesInView = false
        tracker.canStart = { [weak self] point in self?.pick(at: point) ?? false }
        tracker.addTarget(self, action: #selector(handle))
        host.addGestureRecognizer(tracker)
    }

    private func pick(at point: CGPoint) -> Bool {
        guard let host, let view = candidates.reversed().first(where: {
            $0.point(inside: $0.convert(point, from: host), with: nil)
        }) else { return false }
        held = view
        offset = CGPoint(x: view.center.x - point.x, y: view.center.y - point.y)
        return true
    }

    @objc private func handle() {
        guard let host, let view = held else { return }
        let point = tracker.location
        switch tracker.state {
        case .began:
            host.bringSubviewToFront(view)
            UIView.animate(withDuration: 0.1) { view.transform = view.transform.scaledBy(x: 1.08, y: 1.08) }
            Haptics.light()
        case .changed:
            view.center = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        case .ended, .cancelled, .failed:
            held = nil
            onRelease?(view, view.center, tracker.releaseVelocity)
        default:
            break
        }
    }
}

/// A thrown object in flight; it snaps onto the target if it would land close, otherwise it lands short, long or wide.
@MainActor
final class FlickFlight {
    enum Miss {
        case soft, hard, wide
    }

    var onHit: (() -> Void)?
    var onMiss: ((Miss, CGPoint) -> Void)?

    /// Seconds of swipe speed the object carries: a 1200 pt/s swipe travels about 230 points.
    static let reach: CGFloat = 0.19
    private static let gravity: CGFloat = 2600

    private let view: UIView
    private let start: CGPoint
    private let landing: CGPoint
    private let hits: Bool
    private let miss: Miss
    private let duration: CFTimeInterval
    private let apex: CGFloat
    private let rise: CGFloat
    private let startAngle: CGFloat
    private let spin: CGFloat
    private let startScale: CGFloat
    private let endScale: CGFloat
    private var link: CADisplayLink?
    private var begin: CFTimeInterval = 0

    init(view: UIView, velocity: CGPoint, target: CGPoint, hitRadius: CGFloat, assistRadius: CGFloat,
         startAngle: CGFloat, startScale: CGFloat, endScale: CGFloat) {
        let start = view.center
        let speed = max(1, hypot(velocity.x, velocity.y))
        let direction = CGPoint(x: velocity.x / speed, y: velocity.y / speed)
        let distance = speed * Self.reach
        var landing = CGPoint(x: start.x + direction.x * distance, y: start.y + direction.y * distance)

        let toTarget = CGPoint(x: target.x - start.x, y: target.y - start.y)
        let targetDistance = max(1, hypot(toTarget.x, toTarget.y))
        let error = hypot(landing.x - target.x, landing.y - target.y)
        let alignment = (direction.x * toTarget.x + direction.y * toTarget.y) / targetDistance

        var hits = error < hitRadius
        if !hits, alignment > 0.75, error < assistRadius {
            landing = target
            hits = true
        }
        if distance < targetDistance * 0.7 {
            miss = .soft
        } else if distance > targetDistance * 1.35 {
            miss = .hard
        } else {
            miss = .wide
        }

        let flightTime = min(1.0, 0.4 + Double(distance) / 1500)
        self.view = view
        self.start = start
        self.landing = landing
        self.hits = hits
        self.duration = flightTime
        self.apex = min(150, Self.gravity * CGFloat(flightTime * flightTime) / 8)
        self.rise = start.y - target.y
        self.startAngle = startAngle
        self.spin = direction.x * 5
        self.startScale = startScale
        self.endScale = endScale
    }

    func launch() {
        begin = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick() {
        guard view.window != nil else {
            stop()
            return
        }
        let t = CGFloat(min(1, (CACurrentMediaTime() - begin) / duration))
        let ground = CGPoint(x: start.x + (landing.x - start.x) * t, y: start.y + (landing.y - start.y) * t)
        let height = 4 * apex * t * (1 - t)
        view.center = CGPoint(x: ground.x, y: ground.y - height)

        // Farther up the screen means farther away; at the top of the arc it is also nearest the camera.
        let depth = rise > 1 ? max(0, min(1.2, (start.y - ground.y) / rise)) : t
        var scale = startScale + (endScale - startScale) * min(1, depth)
        scale *= 1 + 0.12 * height / max(apex, 1)
        view.transform = CGAffineTransform(rotationAngle: startAngle + spin * t).scaledBy(x: scale, y: scale)

        if t >= 1 {
            stop()
            if hits { onHit?() } else { onMiss?(miss, landing) }
        }
    }
}

extension FarewellSceneView {
    /// A bottom-right pill that throws everything in; also the way through for VoiceOver and Switch Control.
    func installSweepButton(action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = "Sweep it in"
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(hex: 0xF3ECDD, alpha: 0.16)
        config.baseForegroundColor = UIColor(hex: 0xF3ECDD)
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.mono(14, .regular, style: .footnote)
            return attributes
        }
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -30),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
        return button
    }
}

// MARK: - Pieces of a card

struct CardPiece {
    let polygon: UIBezierPath
    /// Bounding box inside the card.
    let box: CGRect
    var center: CGPoint { CGPoint(x: box.midX, y: box.midY) }
}

/// A cut-out of a card's picture that can be picked up.
final class PieceView: UIView {
    let shape: UIBezierPath
    var home = CGPoint.zero
    var homeAngle: CGFloat = 0
    var homeScale: CGFloat = 1

    init(image: UIImage, piece: CardPiece, cardSize: CGSize) {
        let local = piece.polygon.copy() as! UIBezierPath
        local.apply(CGAffineTransform(translationX: -piece.box.minX, y: -piece.box.minY))
        shape = local
        super.init(frame: CGRect(origin: .zero, size: piece.box.size))
        isAccessibilityElement = false
        layer.contents = image.cgImage
        layer.contentsScale = image.scale
        layer.contentsRect = CGRect(x: piece.box.minX / cardSize.width, y: piece.box.minY / cardSize.height,
                                    width: piece.box.width / cardSize.width, height: piece.box.height / cardSize.height)
        let mask = CAShapeLayer()
        mask.path = local.cgPath
        mask.frame = bounds
        layer.mask = mask
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Generous: thin slivers are still easy to grab.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        shape.contains(point) || hypot(point.x - bounds.midX, point.y - bounds.midY) < 28
    }
}

/// How each kind of card breaks up: paper tears, clapperboard snaps, record shatters.
enum CardPieces {
    static func make(kind: CardKind, size: CGSize, seed: Int32) -> [CardPiece] {
        var rng = BackdropRandom(seed: Int(seed) &+ 71)
        let rect = CGRect(origin: .zero, size: size)
        switch kind {
        case .podcast:
            return glass(in: rect, rng: &rng)
        case .video:
            let band = ClapperboardBackdrop.stickBand
            var pieces = grid(in: CGRect(x: 0, y: band, width: size.width, height: size.height - band),
                              cols: 3, rows: 1, tear: 0, rng: &rng)
            let stick = UIBezierPath(rect: CGRect(x: 0, y: 0, width: size.width, height: band))
            pieces.append(CardPiece(polygon: stick, box: stick.bounds))
            return pieces
        default:
            return grid(in: rect, cols: 2, rows: 2, tear: 6, rng: &rng)
        }
    }

    private struct Edge: Hashable { let a: Int; let b: Int }

    /// A jittered grid of cells. With `tear` above zero the shared edges are ragged, like ripped paper.
    private static func grid(in rect: CGRect, cols: Int, rows: Int, tear: CGFloat, rng: inout BackdropRandom) -> [CardPiece] {
        let cellW = rect.width / CGFloat(cols)
        let cellH = rect.height / CGFloat(rows)
        var points: [CGPoint] = []
        for r in 0...rows {
            for c in 0...cols {
                var x = rect.minX + CGFloat(c) * cellW
                var y = rect.minY + CGFloat(r) * cellH
                if c > 0, c < cols { x += (rng.next() - 0.5) * cellW * 0.25 }
                if r > 0, r < rows { y += (rng.next() - 0.5) * cellH * 0.25 }
                points.append(CGPoint(x: x, y: y))
            }
        }
        func index(_ r: Int, _ c: Int) -> Int { r * (cols + 1) + c }

        var midpoints: [Edge: CGPoint] = [:]
        func middle(_ i: Int, _ j: Int) -> CGPoint {
            let key = Edge(a: min(i, j), b: max(i, j))
            if let cached = midpoints[key] { return cached }
            let p = points[key.a], q = points[key.b]
            var m = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            let onBorder = (p.x == q.x && (p.x == rect.minX || p.x == rect.maxX))
                || (p.y == q.y && (p.y == rect.minY || p.y == rect.maxY))
            if tear > 0, !onBorder {
                let length = max(1, hypot(q.x - p.x, q.y - p.y))
                let push = (rng.next() - 0.5) * 2 * tear
                m.x += -(q.y - p.y) / length * push
                m.y += (q.x - p.x) / length * push
            }
            midpoints[key] = m
            return m
        }

        var pieces: [CardPiece] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let tl = index(r, c), tr = index(r, c + 1), br = index(r + 1, c + 1), bl = index(r + 1, c)
                let path = UIBezierPath()
                path.move(to: points[tl])
                for (from, to) in [(tl, tr), (tr, br), (br, bl), (bl, tl)] {
                    if tear > 0 { path.addLine(to: middle(from, to)) }
                    path.addLine(to: points[to])
                }
                path.close()
                pieces.append(CardPiece(polygon: path, box: path.bounds))
            }
        }
        return pieces
    }

    /// Cracks radiating from a point of impact split the record into four wedges.
    private static func glass(in rect: CGRect, rng: inout BackdropRandom) -> [CardPiece] {
        let impact = CGPoint(x: rect.width * 0.32, y: rect.height * 0.45)
        let far = hypot(rect.width, rect.height) * 1.6
        let sectors = 4
        let offset = rng.next() * .pi / 2
        let rim: [CGPoint] = (0..<sectors).map { sector in
            let angle = offset + (CGFloat(sector) + (rng.next() - 0.5) * 0.4) * 2 * .pi / CGFloat(sectors)
            return CGPoint(x: impact.x + cos(angle) * far, y: impact.y + sin(angle) * far)
        }
        var pieces: [CardPiece] = []
        for sector in 0..<sectors {
            let path = UIBezierPath()
            path.move(to: impact)
            path.addLine(to: rim[sector])
            path.addLine(to: rim[(sector + 1) % sectors])
            path.close()
            let box = path.bounds.intersection(rect)
            guard box.width > 12, box.height > 12 else { continue }
            pieces.append(CardPiece(polygon: path, box: box))
        }
        return pieces
    }
}

// MARK: - The bin

/// A steel waste bin drawn in two halves so pieces can drop between them.
final class WasteBinView: UIView {
    enum Part { case back, front }

    static let size = CGSize(width: 104, height: 132)
    static let rimHeight: CGFloat = 24

    private let part: Part

    init(part: Part) {
        self.part = part
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let w = bounds.width, h = bounds.height
        let rimH = Self.rimHeight
        let topW: CGFloat = 96, bottomW: CGFloat = 72
        let rim = CGRect(x: (w - topW) / 2, y: 2, width: topW, height: rimH)

        switch part {
        case .back:
            UIColor(hex: 0x1E1B18).setFill()
            UIBezierPath(ovalIn: rim).fill()
            UIColor(hex: 0x9A9C9F).setStroke()
            let outline = UIBezierPath(ovalIn: rim)
            outline.lineWidth = 3
            outline.stroke()

        case .front:
            // Shadow on the floor.
            UIColor(white: 0, alpha: 0.25).setFill()
            UIBezierPath(ovalIn: CGRect(x: (w - 92) / 2, y: h - 14, width: 92, height: 12)).fill()

            let top = rim.midY
            let body = UIBezierPath()
            body.move(to: CGPoint(x: (w - topW) / 2, y: top))
            body.addLine(to: CGPoint(x: (w + topW) / 2, y: top))
            body.addLine(to: CGPoint(x: (w + bottomW) / 2, y: h - 8))
            body.addQuadCurve(to: CGPoint(x: (w - bottomW) / 2, y: h - 8), controlPoint: CGPoint(x: w / 2, y: h + 2))
            body.close()

            context.saveGState()
            body.addClip()
            let colors = [UIColor(hex: 0x91949A).cgColor, UIColor(hex: 0x6F7277).cgColor, UIColor(hex: 0x56595E).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: 0), options: [])
            }
            UIColor(hex: 0x4A4D52, alpha: 0.7).setStroke()
            for fraction in stride(from: 0.2, through: 0.8, by: 0.2) {
                let rib = UIBezierPath()
                rib.move(to: CGPoint(x: (w - topW) / 2 + topW * fraction, y: top))
                rib.addLine(to: CGPoint(x: (w - bottomW) / 2 + bottomW * fraction, y: h - 6))
                rib.lineWidth = 2
                rib.stroke()
            }
            context.restoreGState()

            // Front half of the rim.
            context.saveGState()
            context.clip(to: CGRect(x: 0, y: rim.midY, width: w, height: h))
            UIColor(hex: 0xB9BBBE).setStroke()
            let outline = UIBezierPath(ovalIn: rim)
            outline.lineWidth = 3
            outline.stroke()
            context.restoreGState()
        }
    }
}
