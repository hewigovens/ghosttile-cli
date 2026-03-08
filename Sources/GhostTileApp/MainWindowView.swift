import AppKit
import GhostTileCore
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var vm: AppViewModel
    @State private var dropTargeted = false
    private let runningColumnWidth: CGFloat = 280
    private let managedColumnWidth: CGFloat = 320
    private var windowWidth: CGFloat { runningColumnWidth + managedColumnWidth + 36 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            windowBackground

            HStack(spacing: 12) {
                runningColumn
                managedColumn
            }
            .padding(12)

            oldAppIcon
                .frame(width: 32, height: 32)
                .opacity(0.1)
                .padding(18)
        }
        .frame(width: windowWidth)
        .frame(minHeight: 420, maxHeight: .infinity)
        .background(
            WindowWidthLock(width: windowWidth, minHeight: 420)
        )
        .onAppear { vm.refresh() }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") {}
        } message: {
            Text(vm.errorMessage)
        }
        .sheet(isPresented: Binding(
            get: { vm.sudoCommand != nil },
            set: { if !$0 { vm.sudoCommand = nil } }
        )) {
            SudoCommandSheet(command: vm.sudoCommand ?? "")
        }
    }

    // MARK: - Columns

    private var runningColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader(icon: "app.badge.fill", title: "Running", count: vm.visibleApps.count) {
                EmptyView()
            }
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
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vm.visibleApps.enumerated()), id: \.element.id) { index, app in
                            RunningAppRow(app: app, isLoading: vm.loading.contains(app.id)) {
                                vm.hideRunningApp(app)
                            }
                            if index < vm.visibleApps.count - 1 {
                                Divider().padding(.leading, 78)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: runningColumnWidth)
        .background(columnBackground())
    }

    private var managedColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader(icon: "eye.slash.fill", title: "Managed", count: vm.hiddenApps.count) {
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
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vm.hiddenApps.enumerated()), id: \.element.id) { index, app in
                            ManagedAppRow(
                                app: app,
                                isLoading: vm.loading.contains(app.id),
                                onShow: { vm.showAppInDock(app) },
                                onHide: { vm.hideAppFromDock(app) },
                                onShowInFinder: {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: app.appPath)
                                },
                                onRemove: { vm.removeApp(app) }
                            )
                            if index < vm.hiddenApps.count - 1 {
                                Divider().padding(.leading, 78)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: managedColumnWidth)
        .background(columnBackground(isDropTargeted: dropTargeted))
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleFileDrop(providers)
        }
    }

    private func columnHeader<T: View>(
        icon: String,
        title: String,
        count: Int,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack {
            HStack(spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.07))
                    )
            }
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

    private var windowBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.blue.opacity(0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -140, y: -190)

            Circle()
                .fill(Color.blue.opacity(0.05))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 180, y: 220)
        }
    }

    private func columnBackground(isDropTargeted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor.opacity(0.24) : Color.primary.opacity(0.07),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 14, y: 6)
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

private struct WindowWidthLock: NSViewRepresentable {
    let width: CGFloat
    let minHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(width: width, minHeight: minHeight)
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.width = width
            context.coordinator.minHeight = minHeight
            if window.delegate !== context.coordinator {
                window.delegate = context.coordinator
            }

            let currentHeight = max(window.frame.height, minHeight)
            if abs(window.frame.width - width) > 0.5 {
                var frame = window.frame
                frame.size.width = width
                frame.size.height = currentHeight
                window.setFrame(frame, display: true)
            }

            window.minSize = NSSize(width: width, height: minHeight)
            window.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var width: CGFloat
        var minHeight: CGFloat

        init(width: CGFloat, minHeight: CGFloat) {
            self.width = width
            self.minHeight = minHeight
        }

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            NSSize(width: width, height: max(frameSize.height, minHeight))
        }
    }
}
