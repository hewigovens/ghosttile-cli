import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class MainWindowViewModel: ObservableObject {
    @Published var query = ""
    @Published var dropTargeted = false

    private let store: ManagedAppsStore
    private var subscriptions: Set<AnyCancellable> = []

    init(store: ManagedAppsStore) {
        self.store = store

        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscriptions)
    }

    var managedApps: [ManagedAppItem] {
        store.apps.filter(\.isHidden).filtered(by: query)
    }

    var runningApps: [ManagedAppItem] {
        store.apps.filter {
            !$0.isHidden && !$0.isSIPProtected && !$0.id.hasPrefix("com.apple.")
        }.filtered(by: query)
    }

    var totalManagedCount: Int {
        store.apps.filter(\.isHidden).count
    }

    var runningCount: Int {
        store.apps.filter { !$0.isHidden && !$0.isSIPProtected && !$0.id.hasPrefix("com.apple.") }.count
    }

    var hiddenRunningCount: Int {
        store.apps.filter { $0.isHidden && $0.isRunning }.count
    }

    func selectAppToHide(with vm: AppViewModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an app to hide from the Dock"
        if panel.runModal() == .OK, let url = panel.url {
            vm.hideByURL(url)
        }
    }

    func handleFileDrop(_ providers: [NSItemProvider], vm: AppViewModel) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let urlString = String(data: data, encoding: .utf8),
                      let url = URL(string: urlString),
                      url.pathExtension == "app"
                else { return }
                DispatchQueue.main.async { vm.hideByURL(url) }
            }
        }
        return true
    }
}
