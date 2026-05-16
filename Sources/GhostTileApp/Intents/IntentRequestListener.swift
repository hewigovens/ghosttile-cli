import AppKit
import GhostTileCore

@MainActor
final class IntentRequestListener {
    private weak var viewModel: AppViewModel?
    private var observer: NSObjectProtocol?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: IntentNotifications.name,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handle(notification)
            }
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func handle(_ notification: Notification) {
        guard let viewModel,
              let request = IntentNotifications.parse(notification) else { return }

        switch request.action {
        case .openWindow:
            openMainWindow(viewModel: viewModel)
        case .hide:
            withManagedApp(viewModel: viewModel, bundleId: request.bundleId) { app in
                if app.isRunning {
                    viewModel.setDockVisibility(app, hidden: true)
                } else {
                    viewModel.hideRunningApp(app)
                }
            }
        case .show:
            withManagedApp(viewModel: viewModel, bundleId: request.bundleId) { app in
                if app.isRunning {
                    viewModel.setDockVisibility(app, hidden: false)
                } else {
                    viewModel.activateManagedApp(app)
                }
            }
        case .focus:
            withManagedApp(viewModel: viewModel, bundleId: request.bundleId) { app in
                viewModel.activateManagedApp(app)
            }
        }
    }

    private func withManagedApp(
        viewModel: AppViewModel,
        bundleId: String?,
        action: (ManagedAppItem) -> Void
    ) {
        guard let bundleId, let app = viewModel.managedApp(bundleId: bundleId) else { return }
        action(app)
    }

    private func openMainWindow(viewModel: AppViewModel) {
        NSApp.activate(ignoringOtherApps: true)
        let existing = NSApp.windows.first { window in
            window.identifier?.rawValue == "main" || window.title == "GhostTile"
        }
        if let existing {
            existing.makeKeyAndOrderFront(nil)
        } else if let opener = (NSApp.delegate as? AppDelegate)?.openMainWindow {
            opener()
        }
        viewModel.refreshForPresentation()
    }
}
