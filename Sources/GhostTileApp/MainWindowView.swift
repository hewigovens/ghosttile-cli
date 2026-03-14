import AppKit
import GhostTileCore
import SwiftUI

struct MainWindowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var vm: AppViewModel

    @State private var dropTargeted = false
    @State private var query = ""

    private let runningSidebarWidth: CGFloat = 300

    private var filteredManagedApps: [AppViewModel.AppItem] {
        filter(vm.hiddenApps)
    }

    private var filteredRunningApps: [AppViewModel.AppItem] {
        filter(vm.visibleApps)
    }

    private var totalManagedCount: Int { vm.hiddenApps.count }
    private var runningCount: Int { vm.visibleApps.count }
    private var hiddenRunningCount: Int { vm.hiddenApps.filter(\.isRunning).count }
    private var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            windowBackground

            VStack(spacing: 14) {
                header

                HStack(alignment: .top, spacing: 18) {
                    managedSection
                    runningSidebar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .frame(minWidth: 940, idealWidth: 1040, minHeight: 680, idealHeight: 760)
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

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("GhostTile")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                HStack(spacing: 8) {
                    statPill(title: "Managed", value: totalManagedCount, systemImage: "eye.slash")
                    statPill(title: "Running", value: runningCount, systemImage: "app.badge")
                    statPill(title: "Active Hidden", value: hiddenRunningCount, systemImage: "bolt.horizontal.circle")
                }
            }

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search managed or running apps", text: $query)
                            .textFieldStyle(.plain)
                            .frame(width: 240)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                                lineWidth: 1
                            )
                    )

                    Button("Add App", action: selectAppToHide)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    private var managedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                sectionHeading(
                    title: "Managed Apps",
                    subtitle: "Click a card to reveal or launch."
                )
                Spacer()
                if dropTargeted {
                    Text("Drop to manage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                }
            }

            if filteredManagedApps.isEmpty {
                managedEmptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 220, maximum: 320), spacing: 14),
                            GridItem(.flexible(minimum: 220, maximum: 320), spacing: 14),
                        ],
                        spacing: 14
                    ) {
                        ForEach(filteredManagedApps) { app in
                            ManagedAppCard(
                                app: app,
                                isLoading: vm.loading.contains(app.id),
                                onOpen: { vm.handleAttentionNotificationClick(bundleId: app.id) },
                                onPrimaryAction: {
                                    if app.isRunning {
                                        app.isHiddenFromDock ? vm.showAppInDock(app) : vm.hideAppFromDock(app)
                                    } else {
                                        vm.activateManagedApp(app)
                                    }
                                },
                                onReveal: { vm.revealAppInFinder(app) },
                                onRemove: { vm.removeApp(app) }
                            )
                        }
                    }
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(18)
        .background(sectionBackground(isDropTargeted: dropTargeted))
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleFileDrop(providers)
        }
    }

    private var runningSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                sectionHeading(title: "Running Apps", subtitle: "Hide active apps quickly.")
                Spacer()
                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Refresh")
            }

            if filteredRunningApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nothing available")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Launch an app or remove filters to hide it from the Dock.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.64))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredRunningApps) { app in
                            RunningAppSidebarRow(
                                app: app,
                                isLoading: vm.loading.contains(app.id),
                                onHide: { vm.hideRunningApp(app) }
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(width: runningSidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(16)
        .background(sidebarBackground)
    }

    private var managedEmptyState: some View {
        VStack(spacing: 18) {
            ghostImage
                .frame(width: 60, height: 66)
                .opacity(dropTargeted ? 0.95 : 0.55)
                .scaleEffect(dropTargeted ? 1.08 : 1)
                .animation(.spring(response: 0.28), value: dropTargeted)

            VStack(spacing: 6) {
                Text(query.isEmpty ? "No managed apps yet" : "No matching managed apps")
                    .font(.system(size: 20, weight: .semibold))

                Text(
                    query.isEmpty
                    ? "Add an app or drag one in from Finder to start building your hidden set."
                    : "Try a different search term or clear the search field."
                )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            }

            if query.isEmpty {
                Button("Add App", action: selectAppToHide)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.white.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            dropTargeted
                                ? Color.accentColor.opacity(0.34)
                                : (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.06)),
                            style: StrokeStyle(lineWidth: 1.2, dash: [8, 8])
                        )
                )
        )
    }

    private var windowBackground: some View {
        ZStack {
            if isDarkMode {
                Rectangle()
                    .fill(.ultraThinMaterial)
            } else {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
            }

            LinearGradient(
                colors: [
                    Color.blue.opacity(isDarkMode ? 0.12 : 0.07),
                    Color.clear,
                    Color.orange.opacity(isDarkMode ? 0.05 : 0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(isDarkMode ? 0.12 : 0.07))
                .frame(width: 480, height: 480)
                .blur(radius: 110)
                .offset(x: -240, y: -220)

            Circle()
                .fill(Color.orange.opacity(isDarkMode ? 0.08 : 0.04))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 260, y: 240)

            oldGhostTileWatermark
                .frame(width: 108, height: 108)
                .opacity(isDarkMode ? 0.08 : 0.06)
                .rotationEffect(.degrees(-8))
                .offset(x: 440, y: 300)
        }
        .ignoresSafeArea()
    }

    private func sectionBackground(isDropTargeted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(isDarkMode ? Color.black.opacity(0.18) : Color.white.opacity(0.54))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        isDropTargeted
                            ? Color.accentColor.opacity(0.34)
                            : (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06)),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isDarkMode ? 0.12 : 0.05), radius: 24, y: 10)
    }

    private var sidebarBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(isDarkMode ? Color.black.opacity(0.16) : Color.white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isDarkMode ? 0.1 : 0.05), radius: 20, y: 8)
    }

    private func sectionHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func statPill(title: String, value: Int, systemImage: String) -> some View {
        Label {
            HStack(spacing: 4) {
                Text(title)
                Text("\(value)")
                    .foregroundStyle(.primary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
        )
        .overlay(
            Capsule()
                .stroke(
                    isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private var ghostImage: some View {
        let url = resourceURL("ghost-icon.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "eye.slash.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var oldGhostTileWatermark: some View {
        let url = resourceURL("appIcon-old.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .saturation(isDarkMode ? 0.2 : 0.1)
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

    private func filter(_ apps: [AppViewModel.AppItem]) -> [AppViewModel.AppItem] {
        guard !query.isEmpty else { return apps }
        let needle = query.lowercased()
        return apps.filter { app in
            app.name.lowercased().contains(needle)
                || app.id.lowercased().contains(needle)
                || app.appPath.lowercased().contains(needle)
        }
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
