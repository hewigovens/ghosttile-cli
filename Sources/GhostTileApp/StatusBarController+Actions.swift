import AppKit

extension StatusBarController {
    @objc func activateManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.activateManagedApp(app)
    }

    @objc func showManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.showAppInDock(app)
    }

    @objc func hideManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.hideAppFromDock(app)
    }

    @objc func removeManagedApp(_ sender: NSMenuItem) {
        guard let app = managedApp(from: sender) else { return }
        vm.removeApp(app)
    }
}
