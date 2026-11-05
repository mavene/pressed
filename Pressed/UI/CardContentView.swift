import UIKit

/// One link as a paper card, used on the Pile, the Stack and the press sheet.
final class CardContentView: UIView {
    let paper = PaperCardView()
    private let thumb = ThumbnailView()
    private let kindLabel = UILabel()
    private let titleLabel = UILabel()
    private let siteLabel = UILabel()
    private let stamp = PaddedLabel()
    private let showsStamp: Bool
    private var thumbTop: NSLayoutConstraint!
    private var textTop: NSLayoutConstraint!
    private var minHeight: NSLayoutConstraint!

    private(set) var record: CardRecord?

    init(showsStamp: Bool = true) {
        self.showsStamp = showsStamp
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func build() {
        paper.translatesAutoresizingMaskIntoConstraints = false
        thumb.translatesAutoresizingMaskIntoConstraints = false
        addSubview(paper)
        addSubview(thumb)

        kindLabel.font = Theme.mono(11, .regular, style: .caption2)
        kindLabel.textColor = Theme.inkSoft
        kindLabel.adjustsFontForContentSizeCategory = true

        titleLabel.font = Theme.serif(17, .semibold, style: .headline)
        titleLabel.textColor = Theme.ink
        titleLabel.numberOfLines = 3
        titleLabel.adjustsFontForContentSizeCategory = true

        siteLabel.font = Theme.sans(13, .regular, style: .footnote)
        siteLabel.textColor = Theme.inkSoft
        siteLabel.lineBreakMode = .byTruncatingTail
        siteLabel.adjustsFontForContentSizeCategory = true
        siteLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        siteLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        stamp.font = Theme.mono(11, .bold, style: .caption2)
        stamp.adjustsFontForContentSizeCategory = true
        stamp.textColor = Theme.stampRed
        stamp.layer.borderColor = Theme.stampRed.cgColor
        stamp.layer.borderWidth = 1.5
        stamp.layer.cornerRadius = 3
        stamp.setContentHuggingPriority(.required, for: .horizontal)
        stamp.setContentCompressionResistancePriority(.required, for: .horizontal)
        stamp.isHidden = !showsStamp

        let bottomRow = UIStackView(arrangedSubviews: [siteLabel, stamp])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.spacing = 8

        let textStack = UIStackView(arrangedSubviews: [kindLabel, titleLabel, bottomRow])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 5
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)

        thumbTop = thumb.topAnchor.constraint(equalTo: topAnchor, constant: 14)
        textTop = textStack.topAnchor.constraint(equalTo: topAnchor, constant: 13)
        minHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 92)
        NSLayoutConstraint.activate([
            paper.topAnchor.constraint(equalTo: topAnchor),
            paper.bottomAnchor.constraint(equalTo: bottomAnchor),
            paper.leadingAnchor.constraint(equalTo: leadingAnchor),
            paper.trailingAnchor.constraint(equalTo: trailingAnchor),

            thumb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            thumbTop,
            thumb.widthAnchor.constraint(equalToConstant: 64),
            thumb.heightAnchor.constraint(equalToConstant: 64),
            thumb.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14),

            textStack.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textTop,
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13),

            minHeight
        ])
    }

    /// - Parameter pose: when true the card is tilted and rotated slightly, like paper on a desk.
    func configure(with record: CardRecord, now: Date = Date(), pose: Bool = true) {
        self.record = record
        let level = CurlRules.level(savedAt: record.savedAt, dueAt: record.dueAt, now: now) ?? 3
        paper.kind = record.kind
        paper.seed = record.sealSeed
        paper.level = record.status == .pending ? level : 0
        applyPalette(for: record.kind)
        kindLabel.text = record.kindLine
        titleLabel.text = record.displayTitle
        siteLabel.text = record.displaySite
        thumb.configure(image: ThumbnailCache.shared.image(for: record), kind: record.kind)

        stamp.text = DueLabel.text(dueAt: record.dueAt, now: now)
        let stampTilt = CGFloat((Int(record.sealSeed) % 7) - 3) * .pi / 180
        stamp.transform = CGAffineTransform(rotationAngle: stampTilt)

        if pose {
            applyPose(level: level, seed: record.sealSeed)
        } else {
            layer.transform = CATransform3DIdentity
        }
    }

    /// Light text on the dark clapperboard and record, ink on paper; room for the clapstick.
    private func applyPalette(for kind: CardKind) {
        let palette = kind.cardPalette
        kindLabel.textColor = palette.soft
        titleLabel.textColor = palette.title
        siteLabel.textColor = palette.soft
        stamp.textColor = palette.stamp
        stamp.layer.borderColor = palette.stamp.cgColor
        thumbTop.constant = 14 + palette.topInset
        textTop.constant = 13 + palette.topInset
        minHeight.constant = 92 + palette.topInset

        // Records get a round label; clapperboards a pale frame so the dark picture block shows up.
        thumb.layer.cornerRadius = kind == .podcast ? 32 : 4
        thumb.layer.borderWidth = kind == .video ? 1.5 : 0
        thumb.layer.borderColor = UIColor(hex: 0xF3ECDD, alpha: 0.55).cgColor
    }

    /// Small rotation per card plus a perspective tilt that grows with the curl.
    private func applyPose(level: Int, seed: Int32) {
        let spin = CGFloat((Int(seed) % 9) - 4) * 0.5 * .pi / 180
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 700
        transform = CATransform3DRotate(transform, CGFloat(level) * 3 * .pi / 180, 1, 0, 0)
        transform = CATransform3DRotate(transform, spin, 0, 0, 1)
        layer.transform = transform
    }

    var spokenSummary: String {
        guard let record else { return "" }
        let due = DueLabel.text(dueAt: record.dueAt, now: Date()).lowercased()
        return [record.displayTitle, record.kindLine.lowercased(), due].joined(separator: ", ")
    }
}
