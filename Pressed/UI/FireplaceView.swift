import UIKit

/// Several expired cards get flicked into a fireplace.
final class FireplaceView: FarewellSceneView {
    private static let tossLines = [
        "Into the fire!", "Whoosh.", "It was getting cold anyway.", "Another one.",
        "Tabs, but make it kindling.", "Burn after reading. Or not."
    ]
    private static let maxFlights = 6

    private let records: [CardRecord]
    private let sceneLayer = CALayer()
    private let glow = CAGradientLayer()
    private let flameGroup = CALayer()
    private let sparks = CAEmitterLayer()
    private var wobbleBook: CALayer?
    private var built = false

    // Geometry shared between building and tossing.
    private var mouth = CGPoint.zero
    private var floorY: CGFloat = 0

    init(records: [CardRecord]) {
        self.records = records
        super.init(frame: .zero)
        layer.addSublayer(sceneLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !built, bounds.width > 0, bounds.height > 0 else { return }
        built = true
        buildScene()
    }

    // MARK: Building the room

    private func solid(_ rect: CGRect, _ color: UInt32, radius: CGFloat = 0, in parent: CALayer? = nil) -> CALayer {
        let layer = CALayer()
        layer.frame = rect
        layer.backgroundColor = UIColor(hex: color).cgColor
        layer.cornerRadius = radius
        (parent ?? sceneLayer).addSublayer(layer)
        return layer
    }

    private func buildScene() {
        let w = bounds.width
        let h = bounds.height
        let topY = h * 0.1
        floorY = h * 0.62
        let sceneHeight = floorY - topY

        // Fireplace in the middle, shelves either side.
        let fw = w * 0.44
        let fh = sceneHeight * 0.58
        let fx = (w - fw) / 2
        let fy = floorY - fh

        buildShelf(CGRect(x: 14, y: topY, width: fx - 14 - 14, height: sceneHeight), seed: 3, tipsOver: true)
        buildShelf(CGRect(x: fx + fw + 14, y: topY, width: w - 14 - (fx + fw + 14), height: sceneHeight), seed: 11, tipsOver: false)

        // Floor and rug.
        _ = solid(CGRect(x: 0, y: floorY, width: w, height: 5), 0x3A2A1E)
        let rug = solid(CGRect(x: w * 0.22, y: floorY + 14, width: w * 0.56, height: 18), 0x7A3B34, radius: 9)
        rug.opacity = 0.85

        // Brick body.
        _ = solid(CGRect(x: fx, y: fy, width: fw, height: fh), 0x6B3B2E)
        let mortar = CAShapeLayer()
        let path = UIBezierPath()
        let rowH: CGFloat = 12
        var row = 0
        var y = fy + rowH
        while y < floorY {
            path.move(to: CGPoint(x: fx, y: y))
            path.addLine(to: CGPoint(x: fx + fw, y: y))
            var x = fx + (row % 2 == 0 ? 0 : 14)
            while x < fx + fw {
                path.move(to: CGPoint(x: x, y: y - rowH))
                path.addLine(to: CGPoint(x: x, y: y))
                x += 28
            }
            y += rowH
            row += 1
        }
        mortar.path = path.cgPath
        mortar.strokeColor = UIColor(hex: 0x4A271E).cgColor
        mortar.lineWidth = 1
        sceneLayer.addSublayer(mortar)
        // Keep the mortar inside the body.
        let clip = CAShapeLayer()
        clip.path = UIBezierPath(rect: CGRect(x: fx, y: fy, width: fw, height: fh)).cgPath
        mortar.mask = clip

        // Mantel and hearth.
        _ = solid(CGRect(x: fx - 12, y: fy - 12, width: fw + 24, height: 12), 0x8B6A47, radius: 3)
        _ = solid(CGRect(x: fx - 8, y: floorY - 5, width: fw + 16, height: 7), 0x5C5148, radius: 2)

        // Opening.
        let ow = fw * 0.66
        let oh = fh * 0.66
        let ox = fx + (fw - ow) / 2
        let oy = floorY - 5 - oh
        let opening = solid(CGRect(x: ox, y: oy, width: ow, height: oh), 0x150F0B)
        opening.cornerRadius = 4
        mouth = CGPoint(x: ox + ow / 2, y: oy + oh * 0.55)

        // Warm light spilling onto the room.
        glow.type = .radial
        glow.colors = [UIColor(hex: 0xFF8A2A, alpha: 0.5).cgColor, UIColor(hex: 0xFF8A2A, alpha: 0).cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.frame = CGRect(x: mouth.x - w * 0.5, y: mouth.y - w * 0.4, width: w, height: w * 0.9)
        glow.opacity = 0.5
        sceneLayer.addSublayer(glow)

        // Logs and flames.
        let logY = oy + oh - 10
        let logA = solid(CGRect(x: ox + ow * 0.14, y: logY, width: ow * 0.56, height: 9), 0x3B2616, radius: 4)
        logA.transform = CATransform3DMakeRotation(-0.09, 0, 0, 1)
        let logB = solid(CGRect(x: ox + ow * 0.3, y: logY + 1, width: ow * 0.56, height: 9), 0x4A3220, radius: 4)
        logB.transform = CATransform3DMakeRotation(0.08, 0, 0, 1)
        buildFlames(openingRect: CGRect(x: ox, y: oy, width: ow, height: oh), baseY: logY + 3)

        // Sparks that float up the chimney.
        let cell = CAEmitterCell()
        cell.contents = FarewellSprite.dot(4)
        cell.color = UIColor(hex: 0xFFAA3C).cgColor
        cell.birthRate = 5
        cell.lifetime = 1.6
        cell.lifetimeRange = 0.6
        cell.velocity = 50
        cell.velocityRange = 25
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 6
        cell.yAcceleration = -20
        cell.alphaSpeed = -0.6
        cell.scale = 0.8
        cell.scaleRange = 0.5
        sparks.emitterCells = [cell]
        sparks.emitterShape = .line
        sparks.emitterSize = CGSize(width: ow * 0.4, height: 1)
        sparks.emitterPosition = CGPoint(x: mouth.x, y: logY)
        sparks.renderMode = .additive
        sceneLayer.addSublayer(sparks)

        if !Self.reduceMotion {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.35
            pulse.toValue = 0.6
            pulse.duration = 0.7
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            glow.add(pulse, forKey: "pulse")
        } else {
            sparks.birthRate = 0
        }
    }

    private func buildFlames(openingRect r: CGRect, baseY: CGFloat) {
        let gw = r.width * 0.62
        let gh = r.height * 0.8
        flameGroup.bounds = CGRect(x: 0, y: 0, width: gw, height: gh)
        flameGroup.anchorPoint = CGPoint(x: 0.5, y: 1)
        flameGroup.position = CGPoint(x: r.midX, y: baseY)
        sceneLayer.addSublayer(flameGroup)

        // Back to front: deep orange, orange, yellow.
        let specs: [(x: CGFloat, w: CGFloat, h: CGFloat, color: UInt32, dur: Double)] = [
            (0.50, 0.50, 1.00, 0xD8461A, 0.55),
            (0.22, 0.34, 0.70, 0xE8601C, 0.42),
            (0.78, 0.34, 0.76, 0xE8601C, 0.47),
            (0.50, 0.36, 0.72, 0xF58A1F, 0.38),
            (0.50, 0.20, 0.44, 0xFFD25A, 0.33)
        ]
        for spec in specs {
            let flame = CAShapeLayer()
            let fw = gw * spec.w
            let fh = gh * spec.h
            flame.bounds = CGRect(x: 0, y: 0, width: fw, height: fh)
            flame.anchorPoint = CGPoint(x: 0.5, y: 1)
            flame.position = CGPoint(x: gw * spec.x, y: gh)
            flame.path = FarewellSprite.flamePath(width: fw, height: fh)
            flame.fillColor = UIColor(hex: spec.color).cgColor
            flameGroup.addSublayer(flame)
            guard !Self.reduceMotion else { continue }

            let flicker = CABasicAnimation(keyPath: "transform.scale.y")
            flicker.fromValue = 0.82
            flicker.toValue = 1.12
            flicker.duration = spec.dur
            flicker.autoreverses = true
            flicker.repeatCount = .infinity
            flicker.timeOffset = Double.random(in: 0..<spec.dur)
            flame.add(flicker, forKey: "flicker")

            let sway = CABasicAnimation(keyPath: "transform.rotation.z")
            sway.fromValue = -0.07
            sway.toValue = 0.07
            sway.duration = spec.dur * 1.3
            sway.autoreverses = true
            sway.repeatCount = .infinity
            sway.timeOffset = Double.random(in: 0..<spec.dur)
            flame.add(sway, forKey: "sway")
        }
    }

    private func buildShelf(_ rect: CGRect, seed: UInt64, tipsOver: Bool) {
        _ = solid(rect, 0x4A3322, radius: 3)
        let rows = 4
        let inner = rect.insetBy(dx: 5, dy: 5)
        let rowH = inner.height / CGFloat(rows)
        let palette: [UInt32] = [0x8E2A20, 0x2F6F6A, 0xC9A45A, 0x3B4A6B, 0x6B4E7A, 0xB5623C, 0x55663A]
        var rng = SeededRandom(seed: seed)

        for rowIndex in 0..<rows {
            let rowTop = inner.minY + CGFloat(rowIndex) * rowH
            _ = solid(CGRect(x: inner.minX, y: rowTop + rowH - 4, width: inner.width, height: 4), 0x8B6A47)
            var x = inner.minX + 2
            var bookIndex = 0
            while true {
                let bw = CGFloat(rng.next(in: 7...13))
                if x + bw > inner.maxX - 2 { break }
                let bh = (rowH - 6) * CGFloat(rng.next(in: 68...96)) / 100
                let color = palette[Int(rng.next(in: 0...(palette.count - 1)))]
                let book = CALayer()
                book.bounds = CGRect(x: 0, y: 0, width: bw, height: bh)
                book.anchorPoint = CGPoint(x: 0.5, y: 1)
                book.position = CGPoint(x: x + bw / 2, y: rowTop + rowH - 4)
                book.backgroundColor = UIColor(hex: color).cgColor
                book.cornerRadius = 1
                sceneLayer.addSublayer(book)
                if tipsOver, rowIndex == 1, bookIndex == 2 { wobbleBook = book }
                x += bw + 1
                bookIndex += 1
            }
        }
    }

    // MARK: Playing

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard self?.window != nil else { return }
            work()
        }
    }

    private var recognizer: FlickRecognizer?
    private var sweepButton: UIButton?
    private var papers: [UIView] = []
    private var homes: [ObjectIdentifier: (center: CGPoint, angle: CGFloat)] = [:]
    private var left = 0
    private var inPlay = 0
    private var overflow: [CardRecord] = []
    private var sweeping = false
    private var say: ((String) -> Void)?
    private var finish: (() -> Void)?

    private func makePaper(_ record: CardRecord) -> UIView {
        let paper = UIView(frame: CGRect(x: 0, y: 0, width: 112, height: 72))
        paper.backgroundColor = UIColor(hex: 0xE9D7A6)
        paper.layer.cornerRadius = 4
        paper.layer.borderWidth = 1
        paper.layer.borderColor = UIColor(hex: 0x5A4119, alpha: 0.3).cgColor
        paper.layer.shadowColor = UIColor.black.cgColor
        paper.layer.shadowOpacity = 0.3
        paper.layer.shadowRadius = 3
        paper.layer.shadowOffset = CGSize(width: 0, height: 2)
        let label = UILabel(frame: paper.bounds.insetBy(dx: 8, dy: 6))
        label.text = record.displayTitle
        label.font = Theme.serif(11, .semibold, scaled: false)
        label.textColor = Theme.ink
        label.numberOfLines = 4
        paper.addSubview(label)
        return paper
    }

    override func play(say: @escaping (String) -> Void, finished: @escaping () -> Void) {
        layoutIfNeeded()
        self.say = say
        self.finish = finished
        let interactive = Array(records.prefix(Self.maxFlights))
        overflow = Array(records.dropFirst(Self.maxFlights))
        left = records.count
        inPlay = interactive.count

        // The cards wait in a pile on the floor in front of the fire.
        var rng = BackdropRandom(seed: records.count &* 31)
        let pile = CGPoint(x: bounds.midX, y: floorY + 86)
        for record in interactive {
            let paper = makePaper(record)
            let angle = (rng.next() - 0.5) * 0.5
            let center = CGPoint(x: pile.x + (rng.next() - 0.5) * 36, y: pile.y + (rng.next() - 0.5) * 14)
            paper.center = center
            paper.transform = CGAffineTransform(rotationAngle: angle)
            homes[ObjectIdentifier(paper)] = (center, angle)
            addSubview(paper)
            papers.append(paper)
        }

        let recognizer = FlickRecognizer(host: self)
        recognizer.candidates = papers
        recognizer.onRelease = { [weak self] paper, point, velocity in
            self?.released(paper, at: point, velocity: velocity)
        }
        self.recognizer = recognizer
        sweepButton = installSweepButton { [weak self] in self?.sweepAll() }
        say("Flick them into the fire.")
    }

    private func released(_ paper: UIView, at point: CGPoint, velocity: CGPoint) {
        recognizer?.candidates.removeAll { $0 === paper }
        guard FlickMath.speed(velocity) > FlickMath.minimumThrowSpeed else {
            returnHome(paper)
            return
        }
        launch(paper, velocity: velocity)
    }

    /// Throws a card along an arc; near the fire, it goes in.
    private func launch(_ paper: UIView, velocity: CGPoint) {
        let angle = homes[ObjectIdentifier(paper)]?.angle ?? 0
        let flight = FlickFlight(view: paper, velocity: velocity, target: mouth, hitRadius: 60, assistRadius: 120,
                                 startAngle: angle, startScale: 1.08, endScale: 0.4)
        flight.onHit = { [weak self] in self?.burnUp(paper) }
        flight.onMiss = { [weak self] kind, point in self?.missed(paper, kind, at: point) }
        flight.launch()
    }

    private func missed(_ paper: UIView, _ kind: FlickFlight.Miss, at point: CGPoint) {
        switch kind {
        case .soft: say?("Too soft.")
        case .hard: say?("Too hard.")
        case .wide: say?("Missed.")
        }
        Haptics.light()
        guard bounds.insetBy(dx: -20, dy: -20).contains(point) else {
            paper.alpha = 0
            after(0.3) { [weak self] in self?.reappear(paper) }
            return
        }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut], animations: {
            paper.center.y -= 16
        }, completion: { _ in
            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseIn], animations: {
                paper.center.y += 16
            }, completion: { [weak self] _ in
                self?.after(0.2) { self?.returnHome(paper) }
            })
        })
    }

    private func reappear(_ paper: UIView) {
        guard let home = homes[ObjectIdentifier(paper)] else { return }
        paper.center = home.center
        paper.transform = CGAffineTransform(rotationAngle: home.angle)
        UIView.animate(withDuration: 0.3, animations: { paper.alpha = 1 }, completion: { [weak self] _ in
            self?.backOnPile(paper)
        })
    }

    private func returnHome(_ paper: UIView) {
        guard let home = homes[ObjectIdentifier(paper)] else { return }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, animations: {
            paper.center = home.center
            paper.transform = CGAffineTransform(rotationAngle: home.angle)
        }, completion: { [weak self] _ in
            self?.backOnPile(paper)
        })
    }

    private func backOnPile(_ paper: UIView) {
        if sweeping {
            launch(paper, velocity: sweepVelocity(from: paper.center))
        } else {
            recognizer?.candidates.append(paper)
        }
    }

    private func sweepVelocity(from point: CGPoint) -> CGPoint {
        let dx = mouth.x - point.x, dy = mouth.y - point.y
        let length = max(1, hypot(dx, dy))
        let speed = length / FlickFlight.reach
        return CGPoint(x: dx / length * speed, y: dy / length * speed)
    }

    /// The card reached the fire: it flares and the card goes dark and vanishes.
    private func burnUp(_ paper: UIView) {
        Haptics.light()
        left -= 1
        inPlay -= 1
        flare(big: left == 0)
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut], animations: {
            paper.center = self.mouth
        }, completion: { _ in
            UIView.animate(withDuration: 0.25, animations: {
                paper.alpha = 0
                paper.backgroundColor = UIColor(hex: 0x1F1A16)
            }, completion: { _ in paper.removeFromSuperview() })
        })
        afterThrow()
    }

    private func afterThrow() {
        if inPlay > 0 {
            say?(left == 1 ? "1 to go." : "\(left) to go.")
            return
        }
        guard !overflow.isEmpty else {
            conclude()
            return
        }
        // Past six, the rest go in as one armful.
        say?("The rest go in together.")
        let extra = overflow
        overflow = []
        for (index, record) in extra.enumerated() {
            after(0.4 + Double(index) * 0.22) { [weak self] in
                self?.toss(record, fromLeft: index % 2 == 0, big: index == extra.count - 1)
            }
        }
        after(0.4 + Double(extra.count) * 0.22 + 1.2) { [weak self] in
            self?.left = 0
            self?.conclude()
        }
    }

    private func conclude() {
        sweepButton?.removeFromSuperview()
        recognizer?.isEnabled = false
        // Don't leave the last "1 to go." hanging while the fire settles.
        say?("Returned to the internet.")
        after(0.5) { [weak self] in self?.tipBook() }
        after(1.6) { [weak self] in self?.finish?() }
    }

    private func sweepAll() {
        guard !sweeping else { return }
        sweeping = true
        sweepButton?.removeFromSuperview()
        recognizer?.isEnabled = false
        let remaining = recognizer?.candidates ?? []
        recognizer?.candidates = []
        for (index, paper) in remaining.enumerated() {
            after(Double(index) * 0.18) { [weak self] in
                guard let self else { return }
                self.launch(paper, velocity: self.sweepVelocity(from: paper.center))
            }
        }
        if remaining.isEmpty, inPlay == 0 { afterThrow() }
    }

    /// Cards that didn't fit in the hand-thrown pile fly in from the sides.
    private func toss(_ record: CardRecord, fromLeft: Bool, big: Bool) {
        let paper = makePaper(record)
        addSubview(paper)

        let start = CGPoint(x: fromLeft ? -70 : bounds.width + 70, y: floorY + 50)
        let apex = CGPoint(x: (start.x + mouth.x) / 2, y: floorY - 260)
        let path = UIBezierPath()
        path.move(to: start)
        path.addQuadCurve(to: mouth, controlPoint: apex)

        let duration = 0.75
        paper.center = mouth

        let fly = CAKeyframeAnimation(keyPath: "position")
        fly.path = path.cgPath
        fly.duration = duration
        fly.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = (fromLeft ? 1 : -1) * 5.5
        spin.duration = duration

        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1
        shrink.toValue = 0.35
        shrink.duration = duration

        let group = CAAnimationGroup()
        group.animations = [fly, spin, shrink]
        group.duration = duration
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak paper] in
            self?.flare(big: big)
            UIView.animate(withDuration: 0.25, animations: {
                paper?.alpha = 0
                paper?.backgroundColor = UIColor(hex: 0x1F1A16)
            }, completion: { _ in paper?.removeFromSuperview() })
        }
        paper.layer.add(group, forKey: "toss")
        CATransaction.commit()
    }

    private func flare(big: Bool) {
        Haptics.light()
        let burst = CABasicAnimation(keyPath: "transform.scale")
        burst.fromValue = big ? 1.55 : 1.3
        burst.toValue = 1
        burst.duration = 0.5
        burst.timingFunction = CAMediaTimingFunction(name: .easeOut)
        flameGroup.add(burst, forKey: "flare")

        let spark = sparks.emitterCells?.first
        spark?.birthRate = big ? 90 : 50
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.sparks.emitterCells?.first?.birthRate = 5
        }
    }

    /// One book on the shelf leans out.
    private func tipBook() {
        guard let book = wobbleBook else { return }
        let lean = CASpringAnimation(keyPath: "transform.rotation.z")
        lean.fromValue = 0
        lean.toValue = 0.5
        lean.mass = 1
        lean.stiffness = 90
        lean.damping = 6
        lean.duration = lean.settlingDuration
        book.transform = CATransform3DMakeRotation(0.5, 0, 0, 1)
        book.add(lean, forKey: "lean")
        Haptics.thunk()
    }
}

/// Small deterministic generator so the bookshelves look the same every time.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6364136223846793005 &+ 1442695040888963407
    }

    mutating func next(in range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int((state >> 33) % span)
    }
}
