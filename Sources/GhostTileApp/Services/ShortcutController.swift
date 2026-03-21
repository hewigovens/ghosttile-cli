import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openMainWindow = Self("openMainWindow")
    static let openOverview = Self("openOverview")
}

final class ShortcutController {
    static let shared = ShortcutController()

    private weak var overviewController: OverviewWindowController?
    private var showMainWindow: (() -> Void)?
    private var isRegistered = false

    private init() {}

    func start(
        overviewController: OverviewWindowController,
        showMainWindow: @escaping () -> Void
    ) {
        self.overviewController = overviewController
        self.showMainWindow = showMainWindow

        guard !isRegistered else { return }
        isRegistered = true

        KeyboardShortcuts.onKeyUp(for: .openMainWindow) { [weak self] in
            self?.showMainWindow?()
        }

        KeyboardShortcuts.onKeyUp(for: .openOverview) { [weak self] in
            self?.overviewController?.showOverview()
        }
    }
}
