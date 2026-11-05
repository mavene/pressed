import UIKit

/// How a card breaks up on expiry: clapperboard to dust, record to glass.
@MainActor
enum CardBreakup {
    // MARK: Shared

    private static func makeContainer(frame: CGRect) -> CALayer {
        let container = CALayer()
        container.frame = frame
        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 600
        container.sublayerTransform = perspective
        return container
    }

    private static func piece(_ image: UIImage, rect: CGRect, in size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(origin: .zero, size: rect.size)
        layer.position = CGPoint(x: rect.midX, y: rect.midY)
        layer.contents = image.cgImage
        layer.contentsScale = image.scale
        layer.contentsRect = CGRect(x: rect.minX / size.width, y: rect.minY / size.height,
                                    width: rect.width / size.width, height: rect.height / size.height)
        return layer
    }

    /// Drifts a piece away: sideways with ease-out, down with ease-in (gravity), spinning and fading.
    private static func fall(_ layer: CALayer, delay: Double, duration: Double,
                             dx: CGFloat, dy: CGFloat, spin: CGFloat, scale: CGFloat, flip: CGFloat = 0) {
        let start = layer.position

        let x = CABasicAnimation(keyPath: "position.x")
        x.fromValue = start.x
        x.toValue = start.x + dx
        x.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let y = CABasicAnimation(keyPath: "position.y")
        y.fromValue = start.y
        y.toValue = start.y + dy
        y.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.fromValue = 0
        rotate.toValue = spin

        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1
        shrink.toValue = scale

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.55, 1]

        var animations: [CAAnimation] = [x, y, rotate, shrink, fade]
        if flip != 0 {
            let tumble = CABasicAnimation(keyPath: "transform.rotation.x")
            tumble.fromValue = 0
            tumble.toValue = flip
            animations.append(tumble)
        }

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        layer.add(group, forKey: "fall")
    }

    private static func emitter(in host: UIView, frame: CGRect, shape: CAEmitterLayerEmitterShape,
                                cells: [CAEmitterCell], additive: Bool = false) -> CAEmitterLayer {
        let layer = CAEmitterLayer()
        layer.frame = host.bounds
        layer.emitterShape = shape
        layer.emitterPosition = CGPoint(x: frame.midX, y: frame.midY)
        layer.emitterSize = frame.size
        layer.emitterCells = cells
        layer.renderMode = additive ? .additive : .unordered
        layer.birthRate = 0
        host.layer.addSublayer(layer)
        return layer
    }

    private static func cell(size: CGFloat, color: UIColor, lifetime: Float, velocity: CGFloat,
                             yAcceleration: CGFloat, rate: Float, alphaSpeed: Float,
                             direction: CGFloat = .pi / 2, spread: CGFloat = .pi) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = FarewellSprite.dot(size)
        cell.color = color.cgColor
        cell.birthRate = rate
        cell.lifetime = lifetime
        cell.lifetimeRange = lifetime * 0.4
        cell.velocity = velocity
        cell.velocityRange = velocity * 0.7
        cell.emissionLongitude = direction
        cell.emissionRange = spread
        cell.yAcceleration = yAcceleration
        cell.scale = 0.9
        cell.scaleRange = 0.6
        cell.alphaSpeed = alphaSpeed
        cell.spin = 1
        cell.spinRange = 3
        return cell
    }

    // MARK: Dust (clapperboard)

    /// The clapstick swings open and drops off, then the board crumbles away in grains from the bottom-right corner.
    static func crumbleToDust(image: UIImage, frame: CGRect, in host: UIView, completion: @escaping () -> Void) {
        let size = frame.size
        let container = makeContainer(frame: frame)
        host.layer.addSublayer(container)
        var rng = BackdropRandom(seed: 17)
        let band = ClapperboardBackdrop.stickBand

        // The clapstick: swings open on its hinge, then falls.
        let stick = piece(image, rect: CGRect(x: 0, y: 0, width: size.width, height: band), in: size)
        stick.anchorPoint = CGPoint(x: 0, y: 1)
        stick.position = CGPoint(x: 0, y: band)
        container.addSublayer(stick)
        let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        swing.values = [0, -0.32, 1.0]
        swing.keyTimes = [0, 0.25, 1]
        let drop = CAKeyframeAnimation(keyPath: "position.y")
        drop.values = [band, band, band + 340]
        drop.keyTimes = [0, 0.25, 1]
        drop.timingFunctions = [CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(name: .easeIn)]
        let vanish = CAKeyframeAnimation(keyPath: "opacity")
        vanish.values = [1, 1, 0]
        vanish.keyTimes = [0, 0.7, 1]
        let stickGroup = CAAnimationGroup()
        stickGroup.animations = [swing, drop, vanish]
        stickGroup.duration = 1.3
        stickGroup.beginTime = stick.convertTime(CACurrentMediaTime(), from: nil) + 0.15
        stickGroup.fillMode = .both
        stickGroup.isRemovedOnCompletion = false
        stick.add(stickGroup, forKey: "drop")

        // The board: a grid of grains that let go in a wave.
        let tile: CGFloat = 8
        let columns = Int(ceil(size.width / tile))
        let rows = Int(ceil((size.height - band) / tile))
        for row in 0..<max(rows, 0) {
            for column in 0..<columns {
                let x = CGFloat(column) * tile
                let y = band + CGFloat(row) * tile
                let rect = CGRect(x: x, y: y, width: min(tile, size.width - x), height: min(tile, size.height - y))
                guard rect.width > 0, rect.height > 0 else { continue }
                let grain = piece(image, rect: rect, in: size)
                container.addSublayer(grain)
                let wave = 1 - (rect.midX / size.width + rect.midY / size.height) / 2
                fall(grain,
                     delay: 0.35 + Double(wave) * 0.9 + Double(rng.next()) * 0.25,
                     duration: 0.8 + Double(rng.next()) * 0.5,
                     dx: 10 + rng.next() * 40,
                     dy: 30 + rng.next() * 70,
                     spin: (rng.next() - 0.5) * 3,
                     scale: 0.15)
            }
        }

        // Dust hanging in the air.
        let dust = emitter(in: host, frame: frame, shape: .rectangle, cells: [
            cell(size: 3, color: UIColor(hex: 0xB4A68C), lifetime: 1.8, velocity: 18, yAcceleration: 22,
                 rate: 150, alphaSpeed: -0.45),
            cell(size: 4, color: UIColor(hex: 0x6F665D), lifetime: 2.0, velocity: 14, yAcceleration: 18,
                 rate: 90, alphaSpeed: -0.4)
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dust.birthRate = 1
            Haptics.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { dust.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            container.removeFromSuperlayer()
            completion()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { dust.removeFromSuperlayer() }
    }

    // MARK: Glass (vinyl)

    /// A crack spreads from a point of impact, then the record breaks into shards that fly out and fall.
    static func shatter(image: UIImage, frame: CGRect, in host: UIView, seed: Int32, completion: @escaping () -> Void) {
        let size = frame.size
        let bounds = CGRect(origin: .zero, size: size)
        let container = makeContainer(frame: frame)
        host.layer.addSublayer(container)
        var rng = BackdropRandom(seed: Int(seed) &+ 5)

        // Shards: rings of jittered points around the impact, joined into polygons like cracked glass.
        let impact = CGPoint(x: size.width * 0.32, y: size.height * 0.45)
        let radii: [CGFloat] = [0, 14, 32, 56, 86, 124, 170, 230, hypot(size.width, size.height)]
        let sectors = 14
        var vertices: [[CGPoint]] = []
        for (ringIndex, radius) in radii.enumerated() {
            var ring: [CGPoint] = []
            let ringRadius = ringIndex == 0 ? 0 : radius * (0.9 + 0.2 * rng.next())
            for sector in 0..<sectors {
                let angle = (CGFloat(sector) + (rng.next() - 0.5) * 0.5) * 2 * .pi / CGFloat(sectors)
                ring.append(CGPoint(x: impact.x + cos(angle) * ringRadius, y: impact.y + sin(angle) * ringRadius))
            }
            vertices.append(ring)
        }

        let cracks = UIBezierPath()
        var shards: [(polygon: UIBezierPath, box: CGRect, center: CGPoint)] = []
        for ring in 0..<(radii.count - 1) {
            for sector in 0..<sectors {
                let next = (sector + 1) % sectors
                let corners = [vertices[ring][sector], vertices[ring][next],
                               vertices[ring + 1][next], vertices[ring + 1][sector]]
                let polygon = UIBezierPath()
                polygon.move(to: corners[0])
                corners.dropFirst().forEach { polygon.addLine(to: $0) }
                polygon.close()
                let box = polygon.bounds.intersection(bounds)
                guard box.width > 1, box.height > 1 else { continue }
                shards.append((polygon, box, CGPoint(x: box.midX, y: box.midY)))
                cracks.append(polygon)
            }
        }

        let maxDistance = hypot(size.width, size.height)
        for shard in shards {
            let layer = piece(image, rect: shard.box, in: size)
            // The polygon is in card coordinates; the shard layer starts at its bounding box.
            let mask = CAShapeLayer()
            let local = shard.polygon.copy() as! UIBezierPath
            local.apply(CGAffineTransform(translationX: -shard.box.minX, y: -shard.box.minY))
            mask.path = local.cgPath
            mask.frame = CGRect(origin: .zero, size: shard.box.size)
            layer.mask = mask
            container.addSublayer(layer)

            let dx = shard.center.x - impact.x
            let dy = shard.center.y - impact.y
            let distance = max(1, hypot(dx, dy))
            let nearness = 1 - min(1, distance / maxDistance)
            let push = 50 + 120 * nearness
            fall(layer,
                 delay: 0.55 + Double(distance / maxDistance) * 0.2 + Double(rng.next()) * 0.05,
                 duration: 1.0 + Double(rng.next()) * 0.5,
                 dx: dx / distance * push * (0.6 + rng.next() * 0.8),
                 dy: dy / distance * push * 0.5 + 240 + rng.next() * 200,
                 spin: (rng.next() - 0.5) * 7,
                 scale: 0.8,
                 flip: (rng.next() - 0.5) * 4)
        }

        // The cracks flash in, hold for a beat, then vanish as the pieces go.
        let lines = CAShapeLayer()
        lines.path = cracks.cgPath
        lines.fillColor = UIColor.clear.cgColor
        lines.strokeColor = UIColor(white: 1, alpha: 0.8).cgColor
        lines.lineWidth = 0.7
        lines.opacity = 0
        // The outer rings run past the card; only show the cracks that are on it.
        let clip = CAShapeLayer()
        clip.path = UIBezierPath(roundedRect: bounds, cornerRadius: 10).cgPath
        lines.mask = clip
        container.addSublayer(lines)
        let show = CAKeyframeAnimation(keyPath: "opacity")
        show.values = [0, 1, 1, 0]
        show.keyTimes = [0, 0.2, 0.9, 1]
        show.duration = 0.65
        show.fillMode = .forwards
        show.isRemovedOnCompletion = false
        lines.add(show, forKey: "cracks")

        // Glints as it breaks.
        let glints = emitter(in: host, frame: CGRect(x: frame.minX + impact.x, y: frame.minY + impact.y, width: 1, height: 1),
                             shape: .point, cells: [
            cell(size: 2, color: .white, lifetime: 0.7, velocity: 150, yAcceleration: 120, rate: 260,
                 alphaSpeed: -1.2, spread: 2 * .pi)
        ], additive: true)

        Haptics.thunk()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            Haptics.thunk()
            glints.birthRate = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { glints.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            container.removeFromSuperlayer()
            glints.removeFromSuperlayer()
            completion()
        }
    }
}
