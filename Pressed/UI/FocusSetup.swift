import SwiftUI
import UIKit
import FamilyControls

/// Apple's picker is SwiftUI-only. This shows it over a clear screen and reports the choice.
private struct FocusPickerHost: View {
    @State private var selection: FamilyActivitySelection
    @State private var isPresented = true
    let onDone: (FamilyActivitySelection) -> Void

    init(initial: FamilyActivitySelection, onDone: @escaping (FamilyActivitySelection) -> Void) {
        _selection = State(initialValue: initial)
        self.onDone = onDone
    }

    var body: some View {
        Color.clear
            .familyActivityPicker(isPresented: $isPresented, selection: $selection)
            .onChange(of: isPresented) { _, presented in
                if !presented { onDone(selection) }
            }
    }
}

/// The opt-in flow: permission, then the picker, then switch the feature on.
@MainActor
enum FocusSetup {
    /// Turns Focus mode on. `completion(true)` means it is on and has something to lock.
    static func begin(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            do {
                try await FocusController.requestAuthorization()
            } catch {
                showFailure(error, from: presenter)
                completion(false)
                return
            }
            guard FocusController.isAuthorized else {
                showFailure(nil, from: presenter)
                completion(false)
                return
            }
            chooseApps(from: presenter) { chosen in
                if chosen {
                    FocusStore.enabled = true
                    FocusController.sync()
                }
                completion(chosen)
            }
        }
    }

    /// Shows Apple's picker. The Simulator has none, so it skips straight on.
    static func chooseApps(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        if FocusShields.isSimulated {
            Toast.show("Simulator: pretending apps are chosen", in: presenter.view)
            completion(true)
            return
        }
        let host = UIHostingController(rootView: FocusPickerHost(initial: FocusStore.selection ?? FamilyActivitySelection()) { selection in
            // Websites are ignored; only apps and categories count.
            let empty = selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty
            FocusStore.selection = empty ? nil : selection
            presenter.presentedViewController?.dismiss(animated: false) {
                completion(!empty)
            }
        })
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        presenter.present(host, animated: false)
    }

    /// Asked once, after a press, with a plain explanation of what gets locked.
    static func offerIfNeeded(from presenter: UIViewController) {
        guard !AppSettings.hasOfferedFocus, !FocusStore.enabled else { return }
        AppSettings.hasOfferedFocus = true
        let alert = UIAlertController(
            title: "Keep distracting apps closed?",
            message: "Focus mode can lock the apps you choose each evening until you press a link from tonight\u{2019}s stack. You pick the apps, you can always say \u{201C}Not now\u{201D}, and you can turn it off in Settings. It all stays on this iPhone.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Set it up", style: .default) { _ in
            begin(from: presenter) { _ in }
        })
        presenter.present(alert, animated: true)
    }

    private static func showFailure(_ error: Error?, from presenter: UIViewController) {
        var message = "Pressed needs Screen Time access to lock apps. You can allow it later from Settings in Pressed."
        #if DEBUG
        if let error { message += "\n\n(\(error.localizedDescription))" }
        #endif
        let alert = UIAlertController(title: "Focus mode is off", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}
