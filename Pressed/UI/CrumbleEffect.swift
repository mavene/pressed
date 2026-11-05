import UIKit

/// A card turns to flakes of paper and falls away.
enum CrumbleEffect {
    private static let flakeImage: CGImage? = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 6, height: 6))
        }.cgImage
    }()

    /// Plays on top of `view` and fades it out. `completion` runs once the card has gone.
    @MainActor
    static func play(on view: UIView, tint: UIColor = UIColor(hex: 0xE9D7A6), completion: (() -> Void)? = nil) {
        guard !UIAccessibility.isReduceMotionEnabled, let host = view.superview else {
            UIView.animate(withDuration: 0.25, animations: {
                view.alpha = 0
            }, completion: { _ in
                completion?()
            })
            return
        }

        let emitter = CAEmitterLayer()
        emitter.name = "crumble"
        emitter.frame = view.frame
        emitter.emitterShape = .rectangle
        emitter.emitterPosition = CGPoint(x: emitter.bounds.midX, y: emitter.bounds.midY)
        emitter.emitterSize = emitter.bounds.size
        emitter.renderMode = .unordered

        let flake = CAEmitterCell()
        flake.contents = flakeImage
        flake.color = tint.cgColor
        flake.birthRate = 160
        flake.lifetime = 1.3
        flake.lifetimeRange = 0.4
        flake.velocity = 40
        flake.velocityRange = 40
        flake.emissionLongitude = .pi / 2
        flake.emissionRange = .pi / 1.5
        flake.yAcceleration = 170
        flake.spinRange = 6
        flake.scale = 0.9
        flake.scaleRange = 0.6
        flake.scaleSpeed = -0.3
        flake.alphaSpeed = -0.7
        emitter.emitterCells = [flake]
        host.layer.addSublayer(emitter)

        // A short burst, then stop making new flakes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            emitter.removeFromSuperlayer()
        }

        UIView.animate(withDuration: 0.6, delay: 0.05, options: [.curveEaseIn], animations: {
            view.alpha = 0
        }, completion: { _ in
            completion?()
        })
    }

    /// Removes leftover emitters when a cell is reused.
    @MainActor
    static func cleanUp(in host: UIView) {
        host.layer.sublayers?
            .filter { $0.name == "crumble" }
            .forEach { $0.removeFromSuperlayer() }
    }
}
