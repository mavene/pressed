import UIKit

/// Shelf life, the evening nudge and a few helpers.
final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private enum Section: Int, CaseIterable {
        case shelfLife, nudge, focus, help
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.desk

        let back = makeCircleButton(symbol: "chevron.left", label: "Back")
        back.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)

        let title = UILabel()
        title.text = "Settings"
        title.font = Theme.serif(28, .semibold, style: .title1)
        title.textColor = Theme.ink
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header

        let header = UIStackView(arrangedSubviews: [back, title, UIView()])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 14
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: Table

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .shelfLife: return 1
        case .nudge: return AppSettings.nudgeEnabled ? 2 : 1
        case .focus:
            guard FocusStore.enabled else { return 1 }
            #if DEBUG
            return 5
            #else
            return 3
            #endif
        case .help:
            #if DEBUG
            return 6
            #else
            return 2
            #endif
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .shelfLife: return "Shelf life"
        case .nudge: return "Evening nudge"
        case .focus: return "Focus mode"
        case .help: return "Help"
        case .none: return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .shelfLife: return "How long a new link lasts before it crumbles. Links already on your Pile keep their dates."
        case .nudge: return "One notification a day, only when your pile has something waiting."
        case .focus: return FocusController.statusLine
        case .help:
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            return "Pressed \(version). Everything stays on this iPhone."
        case .none: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = Theme.paper0
        cell.selectionStyle = .none
        var content = cell.defaultContentConfiguration()
        content.textProperties.font = Theme.sans(16, .regular, style: .body)
        content.textProperties.color = Theme.ink

        switch (Section(rawValue: indexPath.section), indexPath.row) {
        case (.shelfLife, _):
            let control = UISegmentedControl(items: ["3 days", "7 days", "14 days"])
            let current = [3, 7, 14].firstIndex(of: AppSettings.shelfLifeDays) ?? 1
            control.selectedSegmentIndex = current
            control.addAction(UIAction { [weak control] _ in
                guard let control else { return }
                AppSettings.shelfLifeDays = [3, 7, 14][control.selectedSegmentIndex]
            }, for: .valueChanged)
            control.accessibilityLabel = "Shelf life"
            control.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(control)
            NSLayoutConstraint.activate([
                control.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
                control.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
                control.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                control.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
            ])
            return cell

        case (.nudge, 0):
            content.text = "Daily reminder"
            cell.contentConfiguration = content
            let toggle = UISwitch()
            toggle.isOn = AppSettings.nudgeEnabled
            toggle.onTintColor = Theme.ink
            toggle.addAction(UIAction { [weak self, weak toggle] _ in
                guard let toggle else { return }
                self?.setNudge(enabled: toggle.isOn)
            }, for: .valueChanged)
            cell.accessoryView = toggle
            return cell

        case (.nudge, _):
            content.text = "Time"
            cell.contentConfiguration = content
            let picker = UIDatePicker()
            picker.datePickerMode = .time
            picker.preferredDatePickerStyle = .compact
            var parts = DateComponents()
            parts.hour = AppSettings.nudgeHour
            parts.minute = AppSettings.nudgeMinute
            picker.date = Calendar.current.date(from: parts) ?? Date()
            picker.addAction(UIAction { [weak picker] _ in
                guard let picker else { return }
                let chosen = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
                AppSettings.nudgeHour = chosen.hour ?? 19
                AppSettings.nudgeMinute = chosen.minute ?? 0
                NotificationCenter.default.post(name: .nudgeSettingsDidChange, object: nil)
            }, for: .valueChanged)
            cell.accessoryView = picker
            picker.sizeToFit()
            return cell

        case (.focus, 0):
            content.text = "Lock apps until I press"
            cell.contentConfiguration = content
            let toggle = UISwitch()
            toggle.isOn = FocusStore.enabled
            toggle.onTintColor = Theme.ink
            toggle.addAction(UIAction { [weak self, weak toggle] _ in
                guard let toggle else { return }
                self?.setFocus(enabled: toggle.isOn)
            }, for: .valueChanged)
            cell.accessoryView = toggle
            return cell

        case (.focus, 1):
            content.text = "Locks at"
            cell.contentConfiguration = content
            let picker = UIDatePicker()
            picker.datePickerMode = .time
            picker.preferredDatePickerStyle = .compact
            var parts = DateComponents()
            parts.hour = FocusStore.lockHour
            parts.minute = FocusStore.lockMinute
            picker.date = Calendar.current.date(from: parts) ?? Date()
            // The lock window needs at least 15 minutes before midnight.
            picker.maximumDate = Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: Date())
            picker.addAction(UIAction { [weak self, weak picker] _ in
                guard let picker else { return }
                let chosen = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
                FocusStore.lockHour = chosen.hour ?? 20
                FocusStore.lockMinute = chosen.minute ?? 0
                FocusController.sync()
                self?.refreshFocusFooter()
            }, for: .valueChanged)
            cell.accessoryView = picker
            picker.sizeToFit()
            return cell

        case (.focus, 2):
            content.text = "Apps to lock"
            content.secondaryText = FocusController.selectionSummary()
            content.prefersSideBySideTextAndSecondaryText = true
            content.secondaryTextProperties.color = Theme.inkQuiet
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell

        case (.focus, 3):
            content.text = "Lock now (debug build only)"
            content.textProperties.color = Theme.inkQuiet
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            return cell

        case (.focus, _):
            content.text = "Unlock now (debug build only)"
            content.textProperties.color = Theme.inkQuiet
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            return cell

        case (.help, 0):
            content.text = "How to save a link"
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell

        case (.help, 1):
            content.text = "Replay the intro"
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell

        #if DEBUG
        case (.help, 2):
            content.text = "Add sample links (debug build only)"
            content.textProperties.color = Theme.inkQuiet
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            return cell

        case (.help, 3):
            content.text = "Age the pile by one day (debug build only)"
            content.textProperties.color = Theme.inkQuiet
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            return cell

        case (.help, 4):
            content.text = "Preview: one link expires (debug build only)"
            content.textProperties.color = Theme.inkQuiet
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            return cell

        case (.help, _):
            content.text = "Preview: many links expire (debug build only)"
            content.textProperties.color = Theme.inkQuiet
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            return cell
        #endif
        default:
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .focus {
            didSelectFocusRow(indexPath.row)
            return
        }
        guard Section(rawValue: indexPath.section) == .help else { return }
        switch indexPath.row {
        case 0:
            present(HowToSaveViewController(), animated: true)
        case 1:
            let intro = OnboardingViewController()
            intro.modalPresentationStyle = .fullScreen
            intro.onFinish = { [weak intro] in intro?.dismiss(animated: true) }
            present(intro, animated: true)
        case 2:
            #if DEBUG
            CardStore.shared.debugAddSamples()
            Toast.show("Added sample links", in: view)
            #endif
        case 3:
            #if DEBUG
            CardStore.shared.debugAge(days: 1)
            Toast.show("Aged the pile by one day", in: view)
            #endif
        case 4:
            #if DEBUG
            previewSingleExpiry()
            #endif
        default:
            #if DEBUG
            presentPreview(records: Self.previewRecords(count: 8, kinds: [.article, .video, .podcast]))
            #endif
        }
    }

    #if DEBUG
    // MARK: Expiry previews (nothing is saved; the cards are made up)

    private static func previewRecords(count: Int, kinds: [CardKind]) -> [CardRecord] {
        (0..<count).map { index in
            CardRecord(
                id: UUID(),
                url: URL(string: "https://example.com/preview/\(index)")!,
                title: ["The long read you meant to finish", "A recipe you were definitely going to cook",
                        "That podcast everyone mentioned", "Ten tabs you swore were important",
                        "A video essay, 45 minutes", "Something about productivity"][index % 6],
                siteName: "Preview", imageData: nil, kind: kinds[index % kinds.count], estMinutes: 7,
                savedAt: Date().addingTimeInterval(-8 * 86_400), dueAt: Date().addingTimeInterval(-3_600),
                status: .pending, pressedAt: nil, crumbledAt: nil, rescuedAt: nil, note: nil,
                finish: .none, sealSeed: Int32.random(in: 0..<10_000))
        }
    }

    private func previewSingleExpiry() {
        let sheet = UIAlertController(title: "Which kind of link?", message: nil, preferredStyle: .actionSheet)
        for kind in [CardKind.article, .video, .podcast] {
            sheet.addAction(UIAlertAction(title: kind.label.capitalized, style: .default) { [weak self] _ in
                self?.presentPreview(records: Self.previewRecords(count: 1, kinds: [kind]))
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func presentPreview(records: [CardRecord]) {
        // No `onBurned`: previewing never touches the real pile.
        present(FarewellViewController(records: records), animated: true)
    }
    #endif

    // MARK: Focus mode

    private func setFocus(enabled: Bool) {
        guard enabled else {
            FocusController.disable()
            tableView.reloadSections([Section.focus.rawValue], with: .automatic)
            return
        }
        FocusSetup.begin(from: self) { [weak self] _ in
            self?.tableView.reloadSections([Section.focus.rawValue], with: .automatic)
        }
    }

    private func didSelectFocusRow(_ row: Int) {
        switch row {
        case 2:
            FocusSetup.chooseApps(from: self) { [weak self] chosen in
                if !chosen && FocusStore.selection == nil { FocusController.disable() }
                FocusController.sync()
                self?.tableView.reloadSections([Section.focus.rawValue], with: .automatic)
            }
        case 3:
            #if DEBUG
            FocusController.debugLock()
            Toast.show("Locked", in: view)
            refreshFocusFooter()
            #endif
        case 4:
            #if DEBUG
            FocusController.debugUnlock()
            Toast.show("Unlocked for 15 minutes", in: view)
            refreshFocusFooter()
            #endif
        default:
            break
        }
    }

    private func refreshFocusFooter() {
        tableView.footerView(forSection: Section.focus.rawValue)?.textLabel?.text = FocusController.statusLine
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    // MARK: Nudge switch

    private func setNudge(enabled: Bool) {
        AppSettings.nudgeEnabled = enabled
        tableView.reloadSections([Section.nudge.rawValue], with: .automatic)
        guard enabled else {
            NotificationCenter.default.post(name: .nudgeSettingsDidChange, object: nil)
            return
        }
        Task { @MainActor in
            switch await NudgeScheduler.authorizationStatus() {
            case .notDetermined:
                AppSettings.hasAskedForNotifications = true
                await NudgeScheduler.requestAuthorization()
            case .denied:
                self.showNotificationsOff()
            default:
                break
            }
            NotificationCenter.default.post(name: .nudgeSettingsDidChange, object: nil)
        }
    }

    private func showNotificationsOff() {
        let alert = UIAlertController(
            title: "Notifications are off",
            message: "Turn on notifications for Pressed in the Settings app to get the evening nudge.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
}
