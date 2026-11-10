import UIKit

/// One pressed bookmark, full size: title, your note, dates and the wax seal.
final class BookmarkDetailViewController: UIViewController {
    private let card: CardRecord

    init(card: CardRecord) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.desk
        buildTopBar()
        buildBottomBar()
        buildPaper()
    }

    // MARK: Bars

    private let topBar = UIView()
    private let bottomBar = UIStackView()

    private func buildTopBar() {
        let back = makeCircleButton(symbol: "chevron.left", label: "Back to The Shelf")
        back.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)

        let number = UILabel()
        let ordinal = CardStore.shared.pressedNumber(for: card)
        number.text = String(format: "NO. %02d", ordinal)
        number.font = Theme.mono(12, .regular, style: .caption1)
        number.textColor = Theme.inkSoft
        number.adjustsFontForContentSizeCategory = true

        let more = makeCircleButton(symbol: "ellipsis", label: "More")
        more.menu = UIMenu(children: [
            UIAction(title: "Delete bookmark", image: UIImage(systemName: "trash"), attributes: .destructive) {
                [weak self] _ in
                self?.confirmDelete()
            }
        ])
        more.showsMenuAsPrimaryAction = true

        let row = UIStackView(arrangedSubviews: [back, UIView(), more])
        row.axis = .horizontal
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        number.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(number)
        NSLayoutConstraint.activate([
            // Truly centred, and never closer than 16pt to either button.
            number.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            number.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            number.leadingAnchor.constraint(greaterThanOrEqualTo: back.trailingAnchor, constant: 16),
            number.trailingAnchor.constraint(lessThanOrEqualTo: more.leadingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22)
        ])
        topBarBottom = row.bottomAnchor
    }

    private var topBarBottom: NSLayoutYAxisAnchor!

    private func buildBottomBar() {
        var open = UIButton.Configuration.filled()
        open.title = "Open link"
        open.image = UIImage(systemName: "arrow.up.right.square")
        open.imagePadding = 8
        open.baseBackgroundColor = Theme.ink
        open.baseForegroundColor = Theme.paper0
        open.cornerStyle = .capsule
        open.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28)
        let openButton = UIButton(configuration: open)
        openButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            ReaderCoordinator.open(self.card, from: self)
        }, for: .touchUpInside)

        let share = makeCircleButton(symbol: "square.and.arrow.up", label: "Share link")
        share.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.present(UIActivityViewController(activityItems: [self.card.url], applicationActivities: nil),
                         animated: true)
        }, for: .touchUpInside)

        bottomBar.axis = .horizontal
        bottomBar.spacing = 12
        bottomBar.alignment = .center
        bottomBar.addArrangedSubview(openButton)
        bottomBar.addArrangedSubview(share)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: The bookmark

    private func buildPaper() {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let tassel = TasselView()
        tassel.translatesAutoresizingMaskIntoConstraints = false

        let paper = UIView()
        paper.backgroundColor = Theme.paper0
        paper.layer.cornerRadius = 4
        paper.layer.shadowColor = UIColor(hex: 0x462F14).cgColor
        paper.layer.shadowOpacity = 0.22
        paper.layer.shadowRadius = 12
        paper.layer.shadowOffset = CGSize(width: 0, height: 8)
        paper.transform = CGAffineTransform(rotationAngle: 1.5 * .pi / 180)
        paper.translatesAutoresizingMaskIntoConstraints = false

        let hole = UIView()
        hole.backgroundColor = Theme.desk
        hole.layer.cornerRadius = 7
        hole.translatesAutoresizingMaskIntoConstraints = false

        let kind = UILabel()
        kind.text = "\(card.kind.label) \u{00B7} \(card.displaySite.uppercased())"
        kind.font = Theme.mono(11, .regular, style: .caption2)
        kind.textColor = Theme.inkSoft
        kind.numberOfLines = 2
        kind.adjustsFontForContentSizeCategory = true

        let title = UILabel()
        title.text = card.displayTitle
        title.font = Theme.serif(25, .semibold, style: .title2)
        title.textColor = Theme.ink
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header

        let divider = DashedLineView()
        divider.heightAnchor.constraint(equalToConstant: 2).isActive = true

        let stuckLabel = UILabel()
        stuckLabel.text = "WHAT STUCK"
        stuckLabel.font = Theme.mono(11, .regular, style: .caption2)
        stuckLabel.textColor = Theme.inkSoft
        stuckLabel.adjustsFontForContentSizeCategory = true

        let note = UILabel()
        if let text = card.note, !text.isEmpty {
            note.text = "\u{201C}\(text)\u{201D}"
            note.font = Theme.serif(19, .regular, style: .title3, italic: true)
            note.textColor = Theme.ink
        } else {
            note.text = "No note this time."
            note.font = Theme.serif(17, .regular, style: .body, italic: true)
            note.textColor = Theme.inkQuiet
        }
        note.numberOfLines = 0
        note.adjustsFontForContentSizeCategory = true

        let spacer = UIView()
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"
        let dates = UILabel()
        dates.numberOfLines = 0
        dates.font = Theme.mono(12, .regular, style: .caption1)
        dates.textColor = Theme.inkSoft
        dates.adjustsFontForContentSizeCategory = true
        let pressedDate = card.pressedAt ?? card.savedAt
        dates.text = "SAVED \u{00B7} \(dateFormatter.string(from: card.savedAt).uppercased())\nPRESSED \u{00B7} \(dateFormatter.string(from: pressedDate).uppercased())"

        let seal = WaxSealView(frame: .zero)
        seal.configure(finish: card.finish, seed: card.sealSeed)
        seal.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            seal.widthAnchor.constraint(equalToConstant: 60),
            seal.heightAnchor.constraint(equalToConstant: 60)
        ])

        let caption = FinishRules.caption(for: card.finish)
        let finishName = UILabel()
        finishName.text = caption.name
        finishName.font = Theme.mono(12, .bold, style: .caption1)
        finishName.textColor = Theme.inkSoft
        finishName.adjustsFontForContentSizeCategory = true
        let finishDetail = UILabel()
        finishDetail.text = caption.detail
        finishDetail.font = Theme.sans(13, .regular, style: .footnote)
        finishDetail.textColor = Theme.inkSoft
        finishDetail.numberOfLines = 0
        finishDetail.adjustsFontForContentSizeCategory = true
        let finishText = UIStackView(arrangedSubviews: [finishName, finishDetail])
        finishText.axis = .vertical
        finishText.spacing = 2

        let finishRow = UIStackView(arrangedSubviews: [seal, finishText])
        finishRow.axis = .horizontal
        finishRow.alignment = .center
        finishRow.spacing = 12

        let content = UIStackView(arrangedSubviews: [kind, title, divider, stuckLabel, note, spacer, dates, finishRow])
        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false

        // The cord loops round the strip of paper above the hole: behind the card it runs up to the knot,
        // in front it crosses the top edge and dips into the hole.
        let strand = StrandView()
        strand.translatesAutoresizingMaskIntoConstraints = false

        paper.addSubview(hole)
        paper.addSubview(content)
        paper.addSubview(strand)
        scroll.addSubview(tassel)
        scroll.addSubview(paper)

        let paperWidth = paper.widthAnchor.constraint(equalToConstant: 256)
        paperWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topBarBottom, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            tassel.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            tassel.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            tassel.widthAnchor.constraint(equalToConstant: 24),
            tassel.heightAnchor.constraint(equalToConstant: 56),

            paper.topAnchor.constraint(equalTo: tassel.bottomAnchor, constant: -10),
            paper.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            paperWidth,
            paper.widthAnchor.constraint(lessThanOrEqualTo: scroll.frameLayoutGuide.widthAnchor, constant: -64),
            paper.heightAnchor.constraint(greaterThanOrEqualToConstant: 440),
            paper.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),

            hole.topAnchor.constraint(equalTo: paper.topAnchor, constant: 14),
            hole.centerXAnchor.constraint(equalTo: paper.centerXAnchor),
            hole.widthAnchor.constraint(equalToConstant: 14),
            hole.heightAnchor.constraint(equalToConstant: 14),

            strand.topAnchor.constraint(equalTo: paper.topAnchor, constant: -2),
            strand.centerXAnchor.constraint(equalTo: paper.centerXAnchor),
            strand.widthAnchor.constraint(equalToConstant: 24),
            strand.bottomAnchor.constraint(equalTo: hole.centerYAnchor, constant: 1),

            content.topAnchor.constraint(equalTo: paper.topAnchor, constant: 40),
            content.leadingAnchor.constraint(equalTo: paper.leadingAnchor, constant: 22),
            content.trailingAnchor.constraint(equalTo: paper.trailingAnchor, constant: -22),
            content.bottomAnchor.constraint(equalTo: paper.bottomAnchor, constant: -26)
        ])
    }

    // MARK: Delete

    private func confirmDelete() {
        let alert = UIAlertController(
            title: "Delete this bookmark?",
            message: "It will be removed from The Shelf. The link itself is not affected.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            CardStore.shared.delete(id: self.card.id)
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Drawing helpers

/// The red cord a bookmark hangs from.
private final class TasselView: UIView {
    private let cord = CAShapeLayer()
    private let knot = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        cord.strokeColor = UIColor(hex: 0x9E2F24).cgColor
        cord.fillColor = UIColor.clear.cgColor
        cord.lineWidth = 2.2
        cord.lineCap = .round
        knot.fillColor = UIColor(hex: 0x9E2F24).cgColor
        layer.addSublayer(cord)
        layer.addSublayer(knot)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: w / 2, y: 5))
        path.addCurve(to: CGPoint(x: w / 2, y: h),
                      controlPoint1: CGPoint(x: w * 0.2, y: h * 0.35),
                      controlPoint2: CGPoint(x: w * 0.8, y: h * 0.65))
        cord.frame = bounds
        cord.path = path.cgPath
        knot.frame = bounds
        knot.path = UIBezierPath(ovalIn: CGRect(x: w / 2 - 5, y: 0, width: 10, height: 10)).cgPath
    }
}

/// The front half of the cord's loop: over the top edge of the card and into the hole.
private final class StrandView: UIView {
    private let cord = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        cord.strokeColor = UIColor(hex: 0x9E2F24).cgColor
        cord.fillColor = UIColor.clear.cgColor
        cord.lineWidth = 2.2
        cord.lineCap = .round
        cord.shadowColor = UIColor.black.cgColor
        cord.shadowOpacity = 0.3
        cord.shadowRadius = 1
        cord.shadowOffset = CGSize(width: 0, height: 1)
        layer.addSublayer(cord)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let path = UIBezierPath()
        // Starts exactly where the back strand slips behind the card's top edge (2pt right of centre, 2pt down
        // in this view), so the loop reads as one continuous cord.
        path.move(to: CGPoint(x: w / 2 + 2, y: 2))
        path.addCurve(to: CGPoint(x: w / 2, y: h),
                      controlPoint1: CGPoint(x: w / 2 + 2, y: 2 + (h - 2) * 0.35),
                      controlPoint2: CGPoint(x: w / 2 + 1, y: 2 + (h - 2) * 0.7))
        cord.frame = bounds
        cord.path = path.cgPath
    }
}

private final class DashedLineView: UIView {
    private let line = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        line.strokeColor = Theme.outline.cgColor
        line.lineWidth = 1.5
        line.lineDashPattern = [4, 3]
        layer.addSublayer(line)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.midY))
        line.frame = bounds
        line.path = path.cgPath
    }
}
