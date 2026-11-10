import UIKit

/// "Finished? Press it." A note, a hold-to-press button and a wax seal that lands on the card.
final class PressViewController: UIViewController, UITextFieldDelegate {
    /// Called once after the sheet closes. The record is nil if the card was not pressed.
    var onFinish: ((CardRecord?) -> Void)?

    private static let pressDetent = UISheetPresentationController.Detent.Identifier("press")

    private let card: CardRecord
    private var pressedRecord: CardRecord?
    private var didFinish = false

    private let preview = CardContentView(showsStamp: false)
    private let seal = WaxSealView(frame: .zero)
    private let noteField = PaddedTextField()
    private let titleField = PaddedTextField()
    private var changeObserver: NSObjectProtocol?
    private let holdControl = HoldToPressControl()

    init(card: CardRecord) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            let press = UISheetPresentationController.Detent.custom(identifier: Self.pressDetent) { context in
                min(700, context.maximumDetentValue)
            }
            sheet.detents = [press, .large()]
            sheet.selectedDetentIdentifier = Self.pressDetent
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Layout

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sheet

        let headline = UILabel()
        headline.text = "Finished? Press it."
        headline.font = Theme.serif(26, .semibold, style: .title2)
        headline.textColor = Theme.ink
        headline.textAlignment = .center
        headline.numberOfLines = 0
        headline.adjustsFontForContentSizeCategory = true

        let previewWrap = UIView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.configure(with: card, pose: false)
        preview.paper.level = 0
        seal.translatesAutoresizingMaskIntoConstraints = false
        seal.isHidden = true
        previewWrap.addSubview(preview)
        previewWrap.addSubview(seal)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: previewWrap.topAnchor),
            preview.leadingAnchor.constraint(equalTo: previewWrap.leadingAnchor, constant: 8),
            preview.trailingAnchor.constraint(equalTo: previewWrap.trailingAnchor, constant: -8),
            preview.bottomAnchor.constraint(equalTo: previewWrap.bottomAnchor, constant: -24),
            seal.widthAnchor.constraint(equalToConstant: 76),
            seal.heightAnchor.constraint(equalToConstant: 76),
            seal.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: 10),
            seal.bottomAnchor.constraint(equalTo: preview.bottomAnchor, constant: 26)
        ])

        let fieldLabel = UILabel()
        fieldLabel.text = "What stuck with you?"
        fieldLabel.font = Theme.sans(14, .semibold, style: .subheadline)
        fieldLabel.textColor = Theme.ink
        fieldLabel.adjustsFontForContentSizeCategory = true

        noteField.backgroundColor = Theme.paper0
        noteField.layer.cornerRadius = 12
        noteField.layer.borderWidth = 1
        noteField.layer.borderColor = Theme.outline.cgColor
        noteField.font = Theme.serif(16, .regular, style: .body, italic: true)
        noteField.textColor = Theme.ink
        noteField.attributedPlaceholder = NSAttributedString(
            string: "One line, optional",
            attributes: [.foregroundColor: Theme.inkQuiet])
        noteField.returnKeyType = .done
        noteField.autocapitalizationType = .sentences
        noteField.delegate = self
        noteField.accessibilityLabel = "What stuck with you?"
        noteField.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Title"
        titleLabel.font = Theme.sans(14, .semibold, style: .subheadline)
        titleLabel.textColor = Theme.ink
        titleLabel.adjustsFontForContentSizeCategory = true

        titleField.backgroundColor = Theme.paper0
        titleField.layer.cornerRadius = 12
        titleField.layer.borderWidth = 1
        titleField.layer.borderColor = Theme.outline.cgColor
        titleField.font = Theme.serif(16, .regular, style: .body)
        titleField.textColor = Theme.ink
        titleField.returnKeyType = .next
        titleField.autocapitalizationType = .sentences
        titleField.delegate = self
        titleField.accessibilityLabel = "Title"
        titleField.heightAnchor.constraint(equalToConstant: 50).isActive = true
        updateTitlePlaceholder(for: card)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, titleField])
        titleStack.axis = .vertical
        titleStack.spacing = 8

        let fieldStack = UIStackView(arrangedSubviews: [fieldLabel, noteField])
        fieldStack.axis = .vertical
        fieldStack.spacing = 8

        holdControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.pressNow(note: self.noteField.text)
        }, for: .primaryActionTriggered)

        var withoutNote = UIButton.Configuration.plain()
        withoutNote.attributedTitle = AttributedString(
            "Press without a note",
            attributes: AttributeContainer([
                .font: Theme.sans(15, .regular, style: .subheadline),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: Theme.inkSoft
            ]))
        let withoutNoteButton = UIButton(configuration: withoutNote)
        withoutNoteButton.addAction(UIAction { [weak self] _ in
            self?.pressNow(note: nil)
        }, for: .touchUpInside)

        var notYet = UIButton.Configuration.plain()
        notYet.attributedTitle = AttributedString(
            "Not yet",
            attributes: AttributeContainer([
                .font: Theme.sans(15, .regular, style: .subheadline),
                .foregroundColor: Theme.inkQuiet
            ]))
        let notYetButton = UIButton(configuration: notYet)
        notYetButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [headline, previewWrap, titleStack, fieldStack, holdControl,
                                                   withoutNoteButton, notYetButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(8, after: holdControl)
        stack.setCustomSpacing(0, after: withoutNoteButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = false
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24)
        ])

        startTitleLookup()
    }

    // MARK: Title

    /// The placeholder is the fetched title (or the host until one arrives). Typing over it makes a custom title.
    private func updateTitlePlaceholder(for record: CardRecord) {
        titleField.attributedPlaceholder = NSAttributedString(
            string: record.fetchedTitle,
            attributes: [.foregroundColor: Theme.inkQuiet])
    }

    private func startTitleLookup() {
        guard card.title == nil else { return }
        MetadataService.shared.enrichOnDemand(card)
        changeObserver = NotificationCenter.default.addObserver(
            forName: .cardsDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self, let latest = CardStore.shared.fetchRecord(id: self.card.id) else { return }
            self.updateTitlePlaceholder(for: latest)
        }
    }

    deinit {
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
    }

    // MARK: Pressing

    private func pressNow(note: String?) {
        guard pressedRecord == nil else { return }
        view.endEditing(true)
        guard let updated = CardStore.shared.press(id: card.id, note: note, title: titleField.text) else {
            dismiss(animated: true)
            return
        }
        pressedRecord = updated
        isModalInPresentation = true
        seal.configure(finish: updated.finish, seed: updated.sealSeed)
        seal.drop()
        UIAccessibility.post(notification: .announcement, argument: "Pressed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if (isBeingDismissed || presentingViewController == nil) && !didFinish {
            didFinish = true
            onFinish?(pressedRecord)
        }
    }

    // MARK: UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        sheetPresentationController?.animateChanges {
            self.sheetPresentationController?.selectedDetentIdentifier = .large
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard pressedRecord == nil else { return }
        sheetPresentationController?.animateChanges {
            self.sheetPresentationController?.selectedDetentIdentifier = Self.pressDetent
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === titleField {
            noteField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
