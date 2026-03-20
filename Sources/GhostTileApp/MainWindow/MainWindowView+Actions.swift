import AppKit
import UniformTypeIdentifiers

extension MainWindowView {
    func selectAppToHide() {
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

    func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
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
