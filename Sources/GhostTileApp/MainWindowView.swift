import AppKit
import GhostTileCore
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var vm: AppViewModel
    @State private var dropTargeted = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                runningColumn
                Divider()
                managedColumn
            }

            oldAppIcon
                .frame(width: 32, height: 32)
                .opacity(0.15)
                .padding(12)
        }
        .frame(minWidth: 640, maxWidth: 800, minHeight: 400, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleFileDrop(providers)
        }
        .onAppear { vm.refresh() }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") {}
        } message: {
            Text(vm.errorMessage)
        }
    }

    // MARK: - Columns

    private var runningColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader(icon: "app.badge.fill", title: "Running") { EmptyView() }
            Divider()
            if vm.visibleApps.isEmpty {
                Spacer()
                Text("No apps running")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.visibleApps) { app in
                            RunningAppRow(app: app, isLoading: vm.loading.contains(app.id)) {
                                vm.hideRunningApp(app)
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(minWidth: 280)
    }

    private var managedColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader(icon: "eye.slash.fill", title: "Managed") {
                Button { selectAppToHide() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Divider()
            if vm.hiddenApps.isEmpty {
                Spacer()
                emptyManagedState.padding(16)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.hiddenApps) { app in
                            ManagedAppRow(
                                app: app,
                                isLoading: vm.loading.contains(app.id),
                                onToggle: { vm.toggleAppVisibility(app) },
                                onShowInFinder: {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: app.appPath)
                                },
                                onRemove: { vm.removeApp(app) }
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(minWidth: 280)
    }

    private func columnHeader<T: View>(icon: String, title: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Empty state

    private var emptyManagedState: some View {
        VStack(spacing: 8) {
            ghostImage
                .frame(width: 36, height: 40)
                .opacity(dropTargeted ? 0.8 : 0.3)
                .scaleEffect(dropTargeted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: dropTargeted)
            Text("No hidden apps")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Click + or drag an app here")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var oldAppIcon: some View {
        let url = resourceURL("appIcon-old.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
        }
    }

    @ViewBuilder
    private var ghostImage: some View {
        let url = resourceURL("ghost-icon.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "eye.slash.circle.fill")
                .resizable().aspectRatio(contentMode: .fit).foregroundStyle(.secondary)
        }
    }

    private func resourceURL(_ name: String) -> URL {
        let execURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        return execURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(name)")
    }

    private func selectAppToHide() {
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

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
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
