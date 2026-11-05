import UIKit

/// The pressed bookmarks, hanging from a wooden rail per month, swaying gently.
final class ShelfViewController: UIViewController, UICollectionViewDelegate {
    static let rowHeight: CGFloat = 236
    private static let slotsPerRow = 4

    struct ShelfSection: Hashable {
        let monthKey: String
        let row: Int
        let title: String?
    }

    enum ShelfItem: Hashable {
        case card(UUID)
        case pad(String)
    }

    private var records: [UUID: CardRecord] = [:]
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var headerBottom: NSLayoutYAxisAnchor!
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<ShelfSection, ShelfItem>!

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.desk
        buildHeader()
        buildCollectionView()
        buildDataSource()
        NotificationCenter.default.addObserver(
            self, selector: #selector(cardsChanged), name: .cardsDidChange, object: nil)
        reload(animated: false)
    }

    @objc private func cardsChanged() {
        reload(animated: view.window != nil)
    }

    // MARK: Layout

    private func buildHeader() {
        titleLabel.text = "The Shelf"
        titleLabel.font = Theme.serif(36, .semibold, style: .largeTitle)
        titleLabel.textColor = Theme.ink
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        subtitleLabel.font = Theme.mono(13, .regular, style: .footnote)
        subtitleLabel.textColor = Theme.inkQuiet
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
        headerBottom = stack.bottomAnchor
    }

    private func buildCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / CGFloat(ShelfViewController.slotsPerRow)),
                heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(ShelfViewController.rowHeight)),
                repeatingSubitem: item,
                count: ShelfViewController.slotsPerRow)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 14, trailing: 12)
            if self?.sectionHasHeader(sectionIndex) == true {
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(40)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top)
                section.boundarySupplementaryItems = [header]
            }
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerBottom, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func sectionHasHeader(_ index: Int) -> Bool {
        guard let dataSource else { return false }
        let sections = dataSource.snapshot().sectionIdentifiers
        guard sections.indices.contains(index) else { return false }
        return sections[index].title != nil
    }

    private func buildDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<BookmarkCell, ShelfItem> { [weak self] cell, indexPath, item in
            switch item {
            case .card(let id):
                if let record = self?.records[id] {
                    cell.configure(with: record, slot: indexPath.item)
                } else {
                    cell.configurePad(slot: indexPath.item)
                }
            case .pad:
                cell.configurePad(slot: indexPath.item)
            }
        }
        dataSource = UICollectionViewDiffableDataSource<ShelfSection, ShelfItem>(collectionView: collectionView) {
            collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<MonthHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, indexPath in
            let sections = self?.dataSource.snapshot().sectionIdentifiers ?? []
            header.label.text = sections.indices.contains(indexPath.section) ? sections[indexPath.section].title : nil
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    // MARK: Data

    private func reload(animated: Bool) {
        let pressed = CardStore.shared.fetchPressed()
        var changed: [ShelfItem] = []
        var newRecords: [UUID: CardRecord] = [:]
        for record in pressed {
            newRecords[record.id] = record
            if let old = records[record.id], old != record { changed.append(.card(record.id)) }
        }
        records = newRecords

        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: Date())
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM"
        let titleFormatter = DateFormatter()

        func monthStart(of record: CardRecord) -> Date {
            let date = record.pressedAt ?? record.savedAt
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }

        let grouped = Dictionary(grouping: pressed, by: { monthStart(of: $0) })
        var snapshot = NSDiffableDataSourceSnapshot<ShelfSection, ShelfItem>()
        for month in grouped.keys.sorted(by: >) {
            let items = grouped[month] ?? []
            let key = keyFormatter.string(from: month)
            titleFormatter.dateFormat = calendar.component(.year, from: month) == thisYear ? "LLLL" : "LLLL yyyy"
            let monthTitle = titleFormatter.string(from: month).uppercased()

            var start = 0
            var row = 0
            while start < items.count {
                let end = min(start + Self.slotsPerRow, items.count)
                let slice = items[start..<end]
                let section = ShelfSection(monthKey: key, row: row, title: row == 0 ? monthTitle : nil)
                snapshot.appendSections([section])
                var shelfItems = slice.map { ShelfItem.card($0.id) }
                if slice.count < Self.slotsPerRow {
                    for pad in slice.count..<Self.slotsPerRow {
                        shelfItems.append(.pad("\(key)-\(row)-\(pad)"))
                    }
                }
                snapshot.appendItems(shelfItems, toSection: section)
                start = end
                row += 1
            }
        }

        let present = Set(snapshot.itemIdentifiers)
        snapshot.reconfigureItems(changed.filter { present.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: animated)

        let counts = CardStore.shared.counts()
        subtitleLabel.text = "\(counts.pressed) pressed \u{00B7} \(counts.crumbled) crumbled"
        setNeedsUpdateContentUnavailableConfiguration()
    }

    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if case .card = dataSource.itemIdentifier(for: indexPath) { return true }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard case .card(let id)? = dataSource.itemIdentifier(for: indexPath),
              let record = records[id] else { return }
        navigationController?.pushViewController(BookmarkDetailViewController(card: record), animated: true)
    }

    // MARK: Empty state

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        guard records.isEmpty else {
            contentUnavailableConfiguration = nil
            return
        }
        var config = UIContentUnavailableConfiguration.empty()
        config.image = UIImage(systemName: "bookmark")
        config.imageProperties.tintColor = Theme.inkQuiet
        config.text = "Nothing pressed yet"
        config.textProperties.font = Theme.serif(22, .semibold, style: .title2)
        config.textProperties.color = Theme.ink
        config.secondaryText = "Read something from your Pile and press it. It will hang here."
        config.secondaryTextProperties.color = Theme.inkQuiet
        contentUnavailableConfiguration = config
    }
}

// MARK: - Month header

final class MonthHeaderView: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = Theme.mono(12, .bold, style: .footnote)
        label.textColor = Theme.inkSoft
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

// MARK: - Bookmark cell

/// One slot on a rail: a piece of the rail, and (unless it is filler) a bookmark swinging from a hook.
final class BookmarkCell: UICollectionViewCell {
    private let rail = UIView()
    private let sway = UIView()
    private let hook = UIView()
    private let string = UIView()
    private let bookmark = BookmarkView()
    private var stringHeight: NSLayoutConstraint!
    private var seed: Int32 = 0
    private var isPad = true

    private static let railHeight: CGFloat = 10
    private static let pivotY: CGFloat = 8

    override init(frame: CGRect) {
        super.init(frame: frame)

        rail.backgroundColor = Theme.rail
        rail.layer.shadowColor = UIColor(hex: 0x3C2814).cgColor
        rail.layer.shadowOpacity = 0.35
        rail.layer.shadowRadius = 3
        rail.layer.shadowOffset = CGSize(width: 0, height: 3)
        rail.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rail)

        sway.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        contentView.addSubview(sway)

        hook.layer.cornerRadius = 5
        hook.layer.borderWidth = 2
        hook.layer.borderColor = Theme.brass.cgColor
        hook.translatesAutoresizingMaskIntoConstraints = false
        string.backgroundColor = UIColor(hex: 0x8C7A60)
        string.translatesAutoresizingMaskIntoConstraints = false
        sway.addSubview(hook)
        sway.addSubview(string)
        sway.addSubview(bookmark)

        stringHeight = string.heightAnchor.constraint(equalToConstant: 30)
        NSLayoutConstraint.activate([
            rail.topAnchor.constraint(equalTo: contentView.topAnchor),
            rail.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rail.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rail.heightAnchor.constraint(equalToConstant: Self.railHeight),

            hook.topAnchor.constraint(equalTo: sway.topAnchor),
            hook.centerXAnchor.constraint(equalTo: sway.centerXAnchor),
            hook.widthAnchor.constraint(equalToConstant: 10),
            hook.heightAnchor.constraint(equalToConstant: 10),

            string.topAnchor.constraint(equalTo: hook.bottomAnchor, constant: -1),
            string.centerXAnchor.constraint(equalTo: sway.centerXAnchor),
            string.widthAnchor.constraint(equalToConstant: 1.2),
            stringHeight,

            bookmark.topAnchor.constraint(equalTo: string.bottomAnchor),
            bookmark.centerXAnchor.constraint(equalTo: sway.centerXAnchor)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button

        NotificationCenter.default.addObserver(
            self, selector: #selector(motionPreferenceChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Configure

    func configure(with record: CardRecord, slot: Int) {
        isPad = false
        seed = record.sealSeed
        sway.isHidden = false
        bookmark.configure(with: record)
        stringHeight.constant = CGFloat(14 + (Int(record.sealSeed) % 8) * 6)
        styleRail(slot: slot)

        let caption = FinishRules.caption(for: record.finish).name.lowercased()
        accessibilityLabel = "\(record.displayTitle), \(record.kind.label.lowercased()), \(caption)"
        accessibilityHint = "Opens the bookmark"
        isAccessibilityElement = true
        startSway()
    }

    func configurePad(slot: Int) {
        isPad = true
        sway.isHidden = true
        sway.layer.removeAnimation(forKey: "sway")
        isAccessibilityElement = false
        styleRail(slot: slot)
    }

    private func styleRail(slot: Int) {
        let last = slot == 3
        rail.layer.cornerRadius = (slot == 0 || last) ? 5 : 0
        var corners: CACornerMask = []
        if slot == 0 { corners.formUnion([.layerMinXMinYCorner, .layerMinXMaxYCorner]) }
        if last { corners.formUnion([.layerMaxXMinYCorner, .layerMaxXMaxYCorner]) }
        rail.layer.maskedCorners = corners
    }

    // MARK: Sway

    override func layoutSubviews() {
        super.layoutSubviews()
        // The bookmark swings from the hook, so pivot around the top centre.
        sway.bounds = CGRect(x: 0, y: 0,
                             width: contentView.bounds.width,
                             height: max(0, contentView.bounds.height - Self.pivotY))
        sway.center = CGPoint(x: contentView.bounds.midX, y: Self.pivotY)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startSway() } else { sway.layer.removeAnimation(forKey: "sway") }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        sway.layer.removeAnimation(forKey: "sway")
    }

    @objc private func motionPreferenceChanged() {
        startSway()
    }

    private func startSway() {
        sway.layer.removeAnimation(forKey: "sway")
        guard !isPad, window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = -0.045
        animation.toValue = 0.045
        animation.duration = 3.4 + Double(Int(seed) % 20) * 0.1
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.timeOffset = Double(Int(seed) % 37) * 0.1
        sway.layer.add(animation, forKey: "sway")
    }
}
