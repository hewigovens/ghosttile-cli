import AppKit

@MainActor
enum AlertPresenter {
    /// Show a modal NSAlert with a confirm + cancel button. Returns true if the user picked confirm.
    @discardableResult
    static func confirm(
        _ title: String,
        body: String,
        style: NSAlert.Style = .informational,
        confirmButton: String,
        cancelButton: String = "Cancel"
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = style
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: cancelButton)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
