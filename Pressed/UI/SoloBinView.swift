import UIKit

/// One expired card breaks up and its pieces get flicked into a bin.
final class SoloBinView: FarewellSceneView {
    private let record: CardRecord
    private let card = CardContentView(showsStamp: false)
    private let binBack = WasteBinView(part: .back)
    private let binFront = WasteBinView(part: .front)
    private var recognizer: FlickRecognizer?
    private var sweepButton: UIButton?
    private var pieces: [PieceView] = []
    private var left = 0
    private var sweeping = false
    private var say: ((String) -> Void)?
    private var finish: (() -> Void)?

    private var binFrame = CGRect.zero
    private var mouth: CGPoint { CGPoint(x: binFrame.midX, y: binFrame.minY + 2 + WasteBinView.rimHeight / 2) }

    init(record: CardRecord) {
        self.record = record
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func build() {
        card.configure(with: record, pose: false)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -36),
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -50)
        ])
        [binBack, binFront].forEach {
            $0.alpha = 0
            addSubview($0)
        }
    }

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard self?.window != nil else { return }
            work()
        }
    }

    // MARK: Sequence

    override func play(say: @escaping (String) -> Void, finished: @escaping () -> Void) {
        self.say = say
        self.finish = finished
        say("This one didn\u{2019}t make it.")
        layoutIfNeeded()

        let size = WasteBinView.size
        binFrame = CGRect(x: bounds.midX - size.width / 2,
                          y: max(safeAreaInsets.top + 90, bounds.height * 0.44 - size.height / 2 - size.height),
                          width: size.width, height: size.height)
        [binBack, binFront].forEach { $0.frame = binFrame }

        if Self.reduceMotion {
            card.alpha = 0
            UIView.animate(withDuration: 0.3, delay: 0.4, options: []) { [card] in card.alpha = 1 } completion: { [weak self] _ in
                self?.breakApart()
            }
            return
        }

        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) { [card] in
            card.alpha = 1
            card.transform = .identity
        }
        after(1.3) { [weak self] in self?.breakApart() }
    }

    /// The card goes to pieces and the pieces scatter across the desk.
    private func breakApart() {
        layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: card.bounds.size).image { _ in
            card.drawHierarchy(in: card.bounds, afterScreenUpdates: true)
        }
        let frame = card.frame
        let cardPieces = CardPieces.make(kind: record.kind, size: frame.size, seed: record.sealSeed)
        card.alpha = 0

        // Scatter spots: a loose grid across the lower middle of the screen, in random order.
        var rng = BackdropRandom(seed: Int(record.sealSeed) &+ 3)
        let cols = cardPieces.count <= 4 ? 2 : (cardPieces.count <= 6 ? 3 : 5)
        let cellW = (bounds.width - 40) / CGFloat(cols)
        let rowH: CGFloat = 70
        let top = bounds.height * 0.6
        var spots: [CGPoint] = []
        for index in 0..<cardPieces.count {
            let column = CGFloat(index % cols)
            let row = CGFloat(index / cols)
            spots.append(CGPoint(x: 20 + cellW * (column + 0.5), y: top + rowH * (row + 0.5)))
        }
        for i in stride(from: spots.count - 1, to: 0, by: -1) {
            let j = min(i, Int(rng.next() * CGFloat(i + 1)))
            spots.swapAt(i, j)
        }

        pieces = []
        for (index, piece) in cardPieces.enumerated() {
            let view = PieceView(image: image, piece: piece, cardSize: frame.size)
            view.center = CGPoint(x: frame.minX + piece.center.x, y: frame.minY + piece.center.y)
            view.home = CGPoint(x: spots[index].x + (rng.next() - 0.5) * 12, y: spots[index].y + (rng.next() - 0.5) * 10)
            view.homeAngle = (rng.next() - 0.5) * 0.6
            view.homeScale = max(0.45, min(1, cellW * 0.92 / max(piece.box.width, 1), 66 / max(piece.box.height, 1)))
            insertSubview(view, aboveSubview: binBack)
            pieces.append(view)
        }
        left = pieces.count

        if !Self.reduceMotion {
            Haptics.thunk()
            burst(at: CGPoint(x: frame.midX, y: frame.midY), size: frame.size)
        }
        say?("It fell apart.")

        let scatter = Self.reduceMotion ? 0.01 : 0.7
        for (index, view) in pieces.enumerated() {
            UIView.animate(withDuration: scatter, delay: Double(index) * 0.03,
                           usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                view.center = view.home
                view.transform = CGAffineTransform(rotationAngle: view.homeAngle).scaledBy(x: view.homeScale, y: view.homeScale)
            }
        }

        after(Self.reduceMotion ? 0.1 : 1.0) { [weak self] in self?.startGame() }
    }

    /// A puff that suits the material: paper flakes, dust, or glints of glass.
    private func burst(at point: CGPoint, size: CGSize) {
        let cell = CAEmitterCell()
        let glass = record.kind == .podcast
        cell.contents = FarewellSprite.dot(glass ? 2 : 4)
        cell.color = (glass ? UIColor.white : (record.kind == .video ? UIColor(hex: 0xB4A68C) : UIColor(hex: 0xE9D7A6))).cgColor
        cell.birthRate = 300
        cell.lifetime = glass ? 0.7 : 1.2
        cell.lifetimeRange = 0.3
        cell.velocity = glass ? 160 : 60
        cell.velocityRange = 50
        cell.emissionRange = 2 * .pi
        cell.yAcceleration = glass ? 120 : 40
        cell.scale = 0.9
        cell.scaleRange = 0.6
        cell.alphaSpeed = glass ? -1.2 : -0.7
        cell.spin = 1
        cell.spinRange = 4

        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterShape = .rectangle
        emitter.emitterPosition = point
        emitter.emitterSize = size
        emitter.emitterCells = [cell]
        emitter.renderMode = glass ? .additive : .unordered
        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { emitter.removeFromSuperlayer() }
    }

    // MARK: The game

    private func startGame() {
        let appear = Self.reduceMotion ? 0.01 : 0.5
        [binBack, binFront].forEach { $0.transform = CGAffineTransform(scaleX: 0.4, y: 0.4) }
        UIView.animate(withDuration: appear, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.6) {
            [self.binBack, self.binFront].forEach {
                $0.alpha = 1
                $0.transform = .identity
            }
        }
        say?("Flick the pieces into the bin.")

        let recognizer = FlickRecognizer(host: self)
        recognizer.candidates = pieces
        recognizer.onRelease = { [weak self] view, point, velocity in
            guard let piece = view as? PieceView else { return }
            self?.released(piece, at: point, velocity: velocity)
        }
        self.recognizer = recognizer
        sweepButton = installSweepButton { [weak self] in self?.sweepAll() }
    }

    private func released(_ piece: PieceView, at point: CGPoint, velocity: CGPoint) {
        recognizer?.candidates.removeAll { $0 === piece }
        guard FlickMath.speed(velocity) > FlickMath.minimumThrowSpeed() else {
            returnHome(piece)
            return
        }
        launch(piece, velocity: velocity)
    }

    /// Throws a piece along an arc; near the bin, it goes in.
    private func launch(_ piece: PieceView, velocity: CGPoint, scripted: Bool = false) {
        let flight = FlickFlight(view: piece, velocity: velocity, target: mouth, hitRadius: 42, assistRadius: 100,
                                 startAngle: piece.homeAngle, startScale: piece.homeScale * 1.08, endScale: 0.5, scripted: scripted)
        flight.onHit = { [weak self] in self?.sink(piece) }
        flight.onMiss = { [weak self] kind, point in self?.missed(piece, kind, at: point) }
        flight.launch()
    }

    private func missed(_ piece: PieceView, _ kind: FlickFlight.Miss, at point: CGPoint) {
        switch kind {
        case .soft: say?("Too soft.")
        case .hard: say?("Too hard.")
        case .wide: say?("Missed.")
        }
        Haptics.light()
        guard bounds.insetBy(dx: -20, dy: -20).contains(point) else {
            // Sailed clean off the screen: it turns up again on the desk.
            piece.alpha = 0
            after(0.3) { [weak self] in self?.reappear(piece) }
            return
        }
        // It hits the desk and hops once, then slides back.
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut], animations: {
            piece.center.y -= 16
        }, completion: { _ in
            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseIn], animations: {
                piece.center.y += 16
            }, completion: { [weak self] _ in
                self?.after(0.2) { self?.returnHome(piece) }
            })
        })
    }

    private func reappear(_ piece: PieceView) {
        piece.center = piece.home
        piece.transform = CGAffineTransform(rotationAngle: piece.homeAngle).scaledBy(x: piece.homeScale, y: piece.homeScale)
        UIView.animate(withDuration: 0.3, animations: { piece.alpha = 1 }, completion: { [weak self] _ in
            self?.backOnDesk(piece)
        })
    }

    private func returnHome(_ piece: PieceView) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, animations: {
            piece.center = piece.home
            piece.transform = CGAffineTransform(rotationAngle: piece.homeAngle).scaledBy(x: piece.homeScale, y: piece.homeScale)
        }, completion: { [weak self] _ in
            self?.backOnDesk(piece)
        })
    }

    private func backOnDesk(_ piece: PieceView) {
        if sweeping {
            launch(piece, velocity: sweepVelocity(from: piece.center), scripted: true)
        } else {
            recognizer?.candidates.append(piece)
        }
    }

    private func sweepVelocity(from point: CGPoint) -> CGPoint {
        let dx = mouth.x - point.x, dy = mouth.y - point.y
        let length = max(1, hypot(dx, dy))
        let speed = FlickFlight.speed(forDistance: length)
        return CGPoint(x: dx / length * speed, y: dy / length * speed)
    }

    /// The piece reached the bin: it slips behind the front of it and sinks out of sight.
    private func sink(_ piece: PieceView) {
        Haptics.light()
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut], animations: {
            piece.center = self.mouth
        }, completion: { [weak self] _ in
            guard let self else { return }
            self.insertSubview(piece, belowSubview: self.binFront)
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn], animations: {
                piece.center.y += 48
                piece.transform = piece.transform.rotated(by: 0.8)
                piece.alpha = 0
            }, completion: { _ in
                piece.removeFromSuperview()
            })
            self.wobble()
            self.landed()
        })
    }

    private func wobble() {
        let views = [binBack, binFront]
        UIView.animate(withDuration: 0.08, animations: {
            views.forEach { $0.transform = CGAffineTransform(rotationAngle: 0.05).scaledBy(x: 1.03, y: 0.97) }
        }, completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.35, initialSpringVelocity: 0) {
                views.forEach { $0.transform = .identity }
            }
        })
    }

    private func landed() {
        left -= 1
        if left > 0 {
            say?(left == 1 ? "1 to go." : "\(left) to go.")
            return
        }
        // Don't leave the last "1 to go." hanging while the bin finishes wobbling.
        say?("Returned to the internet.")
        Haptics.success()
        sweepButton?.removeFromSuperview()
        recognizer?.isEnabled = false
        after(0.5) { [weak self] in self?.finish?() }
    }

    private func sweepAll() {
        guard !sweeping else { return }
        sweeping = true
        sweepButton?.removeFromSuperview()
        recognizer?.isEnabled = false
        let remaining = recognizer?.candidates.compactMap { $0 as? PieceView } ?? []
        recognizer?.candidates = []
        for (index, piece) in remaining.enumerated() {
            after(Double(index) * 0.14) { [weak self] in
                guard let self else { return }
                self.launch(piece, velocity: self.sweepVelocity(from: piece.center), scripted: true)
            }
        }
    }
}
