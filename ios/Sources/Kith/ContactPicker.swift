import ContactsUI
import SwiftUI

/// The system's multi-select contact picker. Picking shares only the chosen
/// records, so Kith needs no contacts permission or usage description.
struct ContactPicker: UIViewControllerRepresentable {
    var onPick: ([CNContact]) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: ([CNContact]) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping ([CNContact]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onPick(contacts)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}
