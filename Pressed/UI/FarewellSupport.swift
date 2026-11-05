import UIKit

/// Base class for the farewell scenes; calls `finished` when everything has burned.
class FarewellSceneView: UIView {
    func play(say: @escaping (String) -> Void, finished: @escaping () -> Void) {
        finished()
    }

    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
}

enum FarewellSprite {
    /// A white dot. Emitter cells tint it.
    static func dot(_ diameter: CGFloat) -> CGImage? {
        let size = CGSize(width: diameter, height: diameter)
        // Scale 1 so the dot is `diameter` points on screen, not `diameter` points at 3x.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }.cgImage
    }

    /// A teardrop with its point at the top.
    static func flamePath(width w: CGFloat, height h: CGFloat) -> CGPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.68),
                   controlPoint1: CGPoint(x: w * 0.55, y: h * 0.28), controlPoint2: CGPoint(x: w, y: h * 0.42))
        p.addCurve(to: CGPoint(x: w / 2, y: h),
                   controlPoint1: CGPoint(x: w, y: h * 0.88), controlPoint2: CGPoint(x: w * 0.75, y: h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.68),
                   controlPoint1: CGPoint(x: w * 0.25, y: h), controlPoint2: CGPoint(x: 0, y: h * 0.88))
        p.addCurve(to: CGPoint(x: w / 2, y: 0),
                   controlPoint1: CGPoint(x: 0, y: h * 0.42), controlPoint2: CGPoint(x: w * 0.45, y: h * 0.28))
        p.close()
        return p.cgPath
    }
}

/// Chars a card from the bottom up: dark ash behind a glowing ember line that climbs the card.
final class BurnOverlayView: UIView {
    private let gradient = CAGradientLayer()
    private var link: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 1
    private var onProgress: ((CGFloat) -> Void)?
    private var completion: (() -> Void)?
    private var progress: CGFloat = 0
    private let shapeMask = CAShapeLayer()

    /// Clips the burn to an outline (in this view's coordinates) instead of the rounded card rectangle.
    var shapePath: CGPath? {
        didSet {
            shapeMask.path = shapePath
            layer.mask = shapePath == nil ? nil : shapeMask
            layer.cornerRadius = shapePath == nil ? 6 : 0
            clipsToBounds = shapePath == nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.cornerRadius = 6
        clipsToBounds = true
        gradient.colors = [
            UIColor(hex: 0x3A332C).cgColor,
            UIColor(hex: 0x1F1A16).cgColor,
            UIColor(hex: 0xE2551C).cgColor,
            UIColor(hex: 0xFFC247, alpha: 0.85).cgColor,
            UIColor(hex: 0xFFC247, alpha: 0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        layer.addSublayer(gradient)
        apply(0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        shapeMask.frame = bounds
        CATransaction.commit()
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { stop() }
    }

    /// Where the ember line is, as a share of the height measured from the bottom.
    private func apply(_ p: CGFloat) {
        progress = p
        let front = -0.1 + p * 1.2
        func stop(_ v: CGFloat) -> NSNumber { NSNumber(value: Double(min(1, max(0, v)))) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.locations = [stop(0), stop(front - 0.06), stop(front), stop(front + 0.04), stop(front + 0.09)]
        CATransaction.commit()
    }

    func burn(duration: CFTimeInterval, onProgress: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
        self.duration = duration
        self.onProgress = onProgress
        self.completion = completion
        startTime = CACurrentMediaTime()
        link?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        let t = min(1, (CACurrentMediaTime() - startTime) / duration)
        // Slow start, quick finish: paper catches slowly and then goes.
        let eased = CGFloat(t * t * (3 - 2 * t))
        apply(eased)
        onProgress?(eased)
        if t >= 1 {
            stop()
            let done = completion
            completion = nil
            done?()
        }
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }
}

/// Runs a closure every frame with eased progress 0...1.
final class FrameDriver {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private let duration: CFTimeInterval
    private let step: (CGFloat) -> Void
    private var completion: (() -> Void)?

    init(duration: CFTimeInterval, step: @escaping (CGFloat) -> Void) {
        self.duration = duration
        self.step = step
    }

    func run(completion: @escaping () -> Void) {
        self.completion = completion
        start = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func cancel() {
        link?.invalidate()
        link = nil
        completion = nil
    }

    @objc private func tick() {
        let t = min(1, (CACurrentMediaTime() - start) / duration)
        step(CGFloat(t * t * (3 - 2 * t)))
        if t >= 1 {
            link?.invalidate()
            link = nil
            let done = completion
            completion = nil
            done?()
        }
    }
}

extension UIColor {
    /// Lighter (positive) or darker (negative) by a fraction.
    func scaled(by factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> CGFloat { min(1, max(0, v * (1 + factor))) }
        return UIColor(red: c(r), green: c(g), blue: c(b), alpha: a)
    }
}
