import AppKit

@MainActor
enum AlertPresenter {
    /// Risk tint for the confirm button: standard (blue), caution (orange), destructive (red).
    enum Tint {
        case standard, caution, destructive
    }

    /// Show a modal NSAlert with a confirm + cancel button. Returns true if the user picked confirm.
    @discardableResult
    static func confirm(
        _ title: String,
        body: String,
        style: NSAlert.Style = .informational,
        confirmButton: String,
        cancelButton: String = "Cancel",
        tint: Tint = .standard
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = style
        let confirm = alert.addButton(withTitle: confirmButton)
        let cancel = alert.addButton(withTitle: cancelButton)
        switch tint {
        case .standard:
            break
        case .caution:
            confirm.bezelColor = .systemOrange
        case .destructive:
            confirm.hasDestructiveAction = true
        }
        if tint != .standard {
            // Make Cancel the default (Enter) for risky actions — safer, and lets the confirm tint show.
            confirm.keyEquivalent = ""
            cancel.keyEquivalent = "\r"
        }
        return alert.runModal() == .alertFirstButtonReturn
    }
}
