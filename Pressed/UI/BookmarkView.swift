import UIKit

/// A pressed bookmark, drawn differently for each kind of link.
final class BookmarkView: UIView {
    private let titleLabel = UILabel()
    private let seal = WaxSealView(showsLetter: false)
    private var decorations: [UIView] = []

    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    private var titleTop: NSLayoutConstraint!
    private var titleLeading: NSLayoutConstraint!
    private var titleTrailing: NSLayoutConstraint!

    private struct Style {
        var size: CGSize
        var background: UIColor
        var text: UIColor
        var corner: CGFloat
        var titleTop: CGFloat
        var titleInset: CGFloat
        var lines: Int
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false

        layer.shadowColor = UIColor(hex: 0x462F14).cgColor
        layer.shadowOpacity = 0.24
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 5)

        titleLabel.font = Theme.serif(12, .semibold, scaled: false)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        seal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(seal)

        widthConstraint = widthAnchor.constraint(equalToConstant: 64)
        heightConstraint = heightAnchor.constraint(equalToConstant: 150)
        titleTop = titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24)
        titleLeading = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        titleTrailing = titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        NSLayoutConstraint.activate([
            widthConstraint, heightConstraint, titleTop, titleLeading, titleTrailing,
            seal.widthAnchor.constraint(equalToConstant: 20),
            seal.heightAnchor.constraint(equalToConstant: 20),
            seal.centerXAnchor.constraint(equalTo: centerXAnchor),
            seal.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    // MARK: Styles

    private static func style(for record: CardRecord) -> Style {
        let seed = Int(record.sealSeed)
        switch record.kind {
        case .article:
            let colors: [UInt32] = [0xFBF8F1, 0xEFE4CC, 0xF2E1C1]
            return Style(size: CGSize(width: 64, height: CGFloat(148 + (seed % 3) * 8)),
                         background: UIColor(hex: colors[seed % 3]), text: Theme.ink,
                         corner: 3, titleTop: 24, titleInset: 7, lines: 5)
        case .video:
            return Style(size: CGSize(width: 76, height: 112),
                         background: UIColor(hex: 0x2A2622), text: UIColor(hex: 0xF7EFDB),
                         corner: 3, titleTop: 36, titleInset: 8, lines: 3)
        case .recipe:
            return Style(size: CGSize(width: 80, height: 108),
                         background: UIColor(hex: 0xF2E1C1), text: Theme.ink,
                         corner: 3, titleTop: 30, titleInset: 8, lines: 2)
        case .podcast:
            return Style(size: CGSize(width: 84, height: 140),
                         background: UIColor(hex: 0x39424D), text: UIColor(hex: 0xF3ECDD),
                         corner: 3, titleTop: 80, titleInset: 8, lines: 2)
        case .tweet:
            return Style(size: CGSize(width: 76, height: 84),
                         background: UIColor(hex: 0xF7E9A8), text: Theme.ink,
                         corner: 0, titleTop: 12, titleInset: 8, lines: 2)
        case .product:
            return Style(size: CGSize(width: 68, height: 124),
                         background: UIColor(hex: 0xEFE4CC), text: Theme.ink,
                         corner: 6, titleTop: 26, titleInset: 8, lines: 4)
        case .place:
            return Style(size: CGSize(width: 90, height: 86),
                         background: UIColor(hex: 0xE7D2C0), text: Theme.ink,
                         corner: 3, titleTop: 28, titleInset: 8, lines: 2)
        }
    }

    func configure(with record: CardRecord) {
        decorations.forEach { $0.removeFromSuperview() }
        decorations = []

        let style = Self.style(for: record)
        backgroundColor = style.background
        layer.cornerRadius = style.corner
        widthConstraint.constant = style.size.width
        heightConstraint.constant = style.size.height
        titleTop.constant = style.titleTop
        titleLeading.constant = style.titleInset
        titleTrailing.constant = -style.titleInset
        titleLabel.text = record.displayTitle
        titleLabel.textColor = style.text
        titleLabel.numberOfLines = style.lines
        transform = record.kind == .tweet ? CGAffineTransform(rotationAngle: 3 * .pi / 180) : .identity

        seal.configure(finish: record.finish, seed: record.sealSeed)
        addDecorations(for: record.kind)
    }

    private func addDecoration(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(view, at: 0)
        decorations.append(view)
    }

    private func addDecorations(for kind: CardKind) {
        switch kind {
        case .article, .product:
            let hole = UIView()
            hole.backgroundColor = Theme.desk
            hole.layer.cornerRadius = 4
            addDecoration(hole)
            NSLayoutConstraint.activate([
                hole.widthAnchor.constraint(equalToConstant: 8),
                hole.heightAnchor.constraint(equalToConstant: 8),
                hole.centerXAnchor.constraint(equalTo: centerXAnchor),
                hole.topAnchor.constraint(equalTo: topAnchor, constant: 8)
            ])
        case .video:
            let stick = ClapStickView()
            addDecoration(stick)
            NSLayoutConstraint.activate([
                stick.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                stick.leadingAnchor.constraint(equalTo: leadingAnchor),
                stick.trailingAnchor.constraint(equalTo: trailingAnchor),
                stick.heightAnchor.constraint(equalToConstant: 18)
            ])
            let chalk = UIView()
            chalk.backgroundColor = UIColor(hex: 0xF3ECDD, alpha: 0.18)
            addDecoration(chalk)
            NSLayoutConstraint.activate([
                chalk.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
                chalk.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
                chalk.topAnchor.constraint(equalTo: topAnchor, constant: 32),
                chalk.heightAnchor.constraint(equalToConstant: 1)
            ])
        case .recipe:
            let lines = RuledLinesView()
            addDecoration(lines)
            pin(lines)
            let tag = UILabel()
            tag.text = "RECIPE"
            tag.font = Theme.mono(9.5, .bold, scaled: false)
            tag.textColor = UIColor(hex: 0x6A2A1E)
            addDecoration(tag)
            NSLayoutConstraint.activate([
                tag.centerXAnchor.constraint(equalTo: centerXAnchor),
                tag.topAnchor.constraint(equalTo: topAnchor, constant: 9)
            ])
        case .podcast:
            let record = RecordDiscView()
            addDecoration(record)
            NSLayoutConstraint.activate([
                record.widthAnchor.constraint(equalToConstant: 64),
                record.heightAnchor.constraint(equalToConstant: 64),
                record.centerXAnchor.constraint(equalTo: centerXAnchor),
                record.topAnchor.constraint(equalTo: topAnchor, constant: 8)
            ])
        case .tweet:
            break
        case .place:
            let postmark = UIView()
            postmark.layer.cornerRadius = 11
            postmark.layer.borderWidth = 1.5
            postmark.layer.borderColor = Theme.stampRed.withAlphaComponent(0.55).cgColor
            addDecoration(postmark)
            NSLayoutConstraint.activate([
                postmark.widthAnchor.constraint(equalToConstant: 22),
                postmark.heightAnchor.constraint(equalToConstant: 22),
                postmark.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                postmark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
            ])
        }
    }

    private func pin(_ view: UIView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}

/// The striped clapstick across the top of a video bookmark, swung slightly open.
private final class ClapStickView: UIView {
    private let stick = CALayer()
    private let stripes = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        stick.backgroundColor = UIColor(hex: 0x15110F).cgColor
        stick.cornerRadius = 2
        stick.masksToBounds = true
        stick.anchorPoint = CGPoint(x: 0, y: 1)
        stripes.fillColor = UIColor(hex: 0xF3ECDD).cgColor
        stick.addSublayer(stripes)
        layer.addSublayer(stick)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stick.bounds = bounds
        stick.position = CGPoint(x: 0, y: bounds.height)
        stick.transform = CATransform3DMakeRotation(-6 * .pi / 180, 0, 0, 1)
        stripes.frame = bounds
        let path = UIBezierPath()
        var x: CGFloat = -8
        while x < bounds.width + 8 {
            path.move(to: CGPoint(x: x, y: bounds.height))
            path.addLine(to: CGPoint(x: x + 9, y: bounds.height))
            path.addLine(to: CGPoint(x: x + 17, y: 0))
            path.addLine(to: CGPoint(x: x + 8, y: 0))
            path.close()
            x += 20
        }
        stripes.path = path.cgPath
        CATransaction.commit()
    }
}

/// A little record showing through its sleeve: black disc, grooves and a coloured label.
private final class RecordDiscView: UIView {
    private let grooves = CAShapeLayer()
    private let label = CAShapeLayer()
    private let hole = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(hex: 0x131110)
        grooves.fillColor = UIColor.clear.cgColor
        grooves.strokeColor = UIColor(hex: 0x34302C).cgColor
        grooves.lineWidth = 0.6
        label.fillColor = UIColor(hex: 0xB8C9D1).cgColor
        hole.fillColor = UIColor(hex: 0x39424D).cgColor
        [grooves, label, hole].forEach { layer.addSublayer($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath()
        var r: CGFloat = 14
        while r < bounds.width / 2 - 1 {
            path.append(UIBezierPath(arcCenter: c, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: true))
            r += 2.6
        }
        grooves.path = path.cgPath
        label.path = UIBezierPath(arcCenter: c, radius: 11, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        hole.path = UIBezierPath(arcCenter: c, radius: 2, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
    }
}

/// Faint red ruled lines, like an index card.
private final class RuledLinesView: UIView {
    private let lines = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        lines.strokeColor = UIColor(hex: 0x9E2F24, alpha: 0.22).cgColor
        lines.lineWidth = 1
        layer.addSublayer(lines)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        var y: CGFloat = 24
        while y < bounds.height - 4 {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: bounds.width, y: y))
            y += 16
        }
        lines.frame = bounds
        lines.path = path.cgPath
    }
}
