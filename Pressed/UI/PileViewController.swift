import UIKit

/// Home screen. Every saved link waiting to be read, most curled first.
final class PileViewController: UIViewController, UICollectionViewDelegate {
    private let store = CardStore.shared
    private var records: [UUID: CardRecord] = [:]
    private var isSweeping = false

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reconfigureAll()
    }

    @objc private func cardsChanged() {
        reload(animated: view.window != nil)
    }

    // MARK: Header

    private func buildHeader() {
        titleLabel.text = "The Pile"
        titleLabel.font = Theme.serif(36, .semibold, style: .largeTitle)
        titleLabel.textColor = Theme.ink
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        subtitleLabel.font = Theme.mono(13, .regular, style: .footnote)
        subtitleLabel.textColor = Theme.inkQuiet
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let stackButton = makeCircleButton(symbol: "moon.stars", label: "Tonight\u{2019}s stack")
        stackButton.addAction(UIAction { _ in
            AppRouter.shared.go(.stack)
        }, for: .touchUpInside)

        let settingsButton = makeCircleButton(symbol: "slider.horizontal.3", label: "Settings")
        settingsButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsViewController(), animated: true)
        }, for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [stackButton, settingsButton])
        buttons.axis = .horizontal
        buttons.spacing = 10

        let header = UIStackView(arrangedSubviews: [titleStack, UIView(), buttons])
        header.axis = .horizontal
        header.alignment = .top
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22)
        ])
        headerBottom = header.bottomAnchor
    }

    private var headerBottom: NSLayoutYAxisAnchor!

    // MARK: Collection view

    private func buildCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        config.backgroundColor = .clear
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            self?.trailingActions(at: indexPath)
        }
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerBottom, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func buildDataSource() {
        let registration = UICollectionView.CellRegistration<CardCell, UUID> { [weak self] cell, _, id in
            guard let self, let record = self.records[id] else { return }
            cell.configure(with: record)
            cell.accessibilityCustomActions = self.accessibilityActions(for: record)
        }
        dataSource = UICollectionViewDiffableDataSource<Int, UUID>(collectionView: collectionView) {
            collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
    }

    // MARK: Data

    private func reload(animated: Bool) {
        let pending = store.fetchPending()
        var changed: [UUID] = []
        var newRecords: [UUID: CardRecord] = [:]
        for record in pending {
            newRecords[record.id] = record
            if let old = records[record.id], old != record { changed.append(record.id) }
        }
        records = newRecords

        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(pending.map(\.id))
        snapshot.reconfigureItems(changed)
        dataSource.apply(snapshot, animatingDifferences: animated)

        subtitleLabel.text = pending.isEmpty
            ? "nothing waiting"
            : "\(pending.count) waiting \u{00B7} most curled first"
        setNeedsUpdateContentUnavailableConfiguration()
    }

    /// Curl levels depend on the clock, so refresh every visible card.
    private func reconfigureAll() {
        guard dataSource != nil else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: System refresh (launch, foreground)

    /// Picks up shared links and looks up missing titles, then says goodbye to anything past its due date.
    func refreshFromSystem() {
        store.ingestInbox()
        MetadataService.shared.enrichMissing()
        presentFarewellIfNeeded()
    }

    /// Burns one expired card, or several in the fireplace; waits if something else is on screen.
    func presentFarewellIfNeeded() {
        let expired = store.expiredPending(now: Date())
        guard !expired.isEmpty else {
            if isViewLoaded { reconfigureAll() }
            return
        }
        let host: UIViewController = tabBarController ?? self
        guard !isSweeping, host.viewIfLoaded?.window != nil, host.presentedViewController == nil else { return }

        isSweeping = true
        let farewell = FarewellViewController(records: expired)
        farewell.onBurned = { [weak self] in
            guard let self else { return }
            self.store.sweepExpired(now: Date())
            self.isSweeping = false
        }
        host.present(farewell, animated: true)
    }

    // MARK: Actions

    private func open(_ record: CardRecord) {
        ReaderCoordinator.open(record, from: self)
    }

    private func letGo(id: UUID) {
        guard let indexPath = dataSource.indexPath(for: id),
              let cell = collectionView.cellForItem(at: indexPath) as? CardCell else {
            store.crumble(id: id)
            return
        }
        cell.playCrumble { [weak self] in
            self?.store.crumble(id: id)
        }
    }

    private func trailingActions(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let action = UIContextualAction(style: .normal, title: "Let go") { [weak self] _, _, done in
            self?.letGo(id: id)
            done(true)
        }
        action.image = UIImage(systemName: "wind")
        action.backgroundColor = Theme.stampRed
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func accessibilityActions(for record: CardRecord) -> [UIAccessibilityCustomAction] {
        var actions = [
            UIAccessibilityCustomAction(name: "Let go") { [weak self] _ in
                self?.letGo(id: record.id)
                return true
            }
        ]
        return actions
    }

    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath), let record = records[id] else { return }
        open(record)
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              let id = dataSource.itemIdentifier(for: indexPath),
              let record = records[id] else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            var actions: [UIMenuElement] = [
                UIAction(title: "Open", image: UIImage(systemName: "safari")) { _ in
                    self?.open(record)
                },
                UIAction(title: "Copy link", image: UIImage(systemName: "link")) { _ in
                    UIPasteboard.general.url = record.url
                }
            ]
            actions.append(UIAction(title: "Let go", image: UIImage(systemName: "wind"), attributes: .destructive) { _ in
                self?.letGo(id: record.id)
            })
            return UIMenu(children: actions)
        }
    }

    // MARK: Empty state

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        guard records.isEmpty else {
            contentUnavailableConfiguration = nil
            return
        }
        var config = UIContentUnavailableConfiguration.empty()
        config.image = UIImage(systemName: "tray")
        config.imageProperties.tintColor = Theme.inkQuiet
        config.text = "Nothing waiting"
        config.textProperties.font = Theme.serif(22, .semibold, style: .title2)
        config.textProperties.color = Theme.ink
        config.secondaryText = "When you find something to read later, share it to Pressed."
        config.secondaryTextProperties.color = Theme.inkQuiet

        var button = UIButton.Configuration.filled()
        button.title = "How to save a link"
        button.baseBackgroundColor = Theme.ink
        button.baseForegroundColor = Theme.paper0
        button.cornerStyle = .capsule
        config.button = button
        config.buttonProperties.primaryAction = UIAction { [weak self] _ in
            self?.present(HowToSaveViewController(), animated: true)
        }
        contentUnavailableConfiguration = config
    }
}

// MARK: - Cell

final class CardCell: UICollectionViewListCell {
    private let content = CardContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundConfiguration = UIBackgroundConfiguration.clear()
        automaticallyUpdatesBackgroundConfiguration = false
        content.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(with record: CardRecord) {
        content.alpha = 1
        content.configure(with: record)
        accessibilityLabel = content.spokenSummary
        accessibilityHint = "Opens the link"
    }

    func playCrumble(completion: (() -> Void)? = nil) {
        CrumbleEffect.play(on: content, completion: completion)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        CrumbleEffect.cleanUp(in: contentView)
        content.alpha = 1
    }
}
