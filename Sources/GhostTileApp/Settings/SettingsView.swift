import AppKit
import GhostTileCore
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @AppStorage("autoHideOnLaunch") var autoHideOnLaunch = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showInDock") var showInDock = false
    @StateObject var viewModel = SettingsViewModel()
    @ObservedObject var updater: SparkleUpdater

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }

            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "command") }

            cliTab
                .tabItem { Label("CLI", systemImage: "terminal") }

            permissionsTab
                .tabItem { Label("Permissions", systemImage: "lock.shield") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 520)
        .onAppear {
            viewModel.syncLaunchAtLoginState(launchAtLogin: $launchAtLogin)
            viewModel.checkCLIInstalled()
        }
    }

    // MARK: - General

    private var generalTab: some View {
        ZStack {
            SettingsUI.settingsBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSectionCard(title: "General", symbol: "slider.horizontal.3") {
                        VStack(spacing: 0) {
                            SettingsUI.settingsRow(
                                title: "Show GhostTile in Dock",
                                symbol: "dock.rectangle",
                                toggle: Binding(
                                    get: { showInDock },
                                    set: { newValue in
                                        showInDock = newValue
                                        viewModel.setShowInDock(newValue)
                                    }
                                )
                            )

                            Divider().padding(.leading, 42)

                            SettingsUI.settingsRow(
                                title: "Auto-hide apps on launch",
                                symbol: "arrow.triangle.2.circlepath",
                                toggle: $autoHideOnLaunch
                            )

                            Divider().padding(.leading, 42)

                            SettingsUI.settingsRow(
                                title: "Launch at login",
                                symbol: "power.circle",
                                toggle: Binding(
                                    get: { launchAtLogin },
                                    set: { viewModel.setLaunchAtLogin($0, launchAtLogin: $launchAtLogin) }
                                )
                            )
                        }
                    }

                    SettingsSectionCard(title: "Updates", symbol: "arrow.triangle.2.circlepath.circle") {
                        VStack(spacing: 0) {
                            SettingsUI.settingsRow(
                                title: "Check for updates automatically",
                                symbol: "arrow.triangle.2.circlepath.circle",
                                toggle: Binding(
                                    get: { updater.autoChecksEnabled },
                                    set: { updater.autoChecksEnabled = $0 }
                                )
                            )

                            Divider().padding(.leading, 42)

                            SettingsUI.actionRow(
                                title: "Check for Updates",
                                symbol: "arrow.clockwise.circle",
                                action: { updater.checkForUpdates() }
                            )
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        ZStack {
            SettingsUI.settingsBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSectionCard(title: "Shortcuts", symbol: "command") {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsUI.shortcutRow(
                                title: "Open Main Window",
                                symbol: "macwindow",
                                description: "Bring GhostTile's main workspace forward from anywhere.",
                                recorder: { KeyboardShortcuts.Recorder(for: .openMainWindow) }
                            )

                            SettingsUI.shortcutRow(
                                title: "Open Overview",
                                symbol: "square.grid.2x2",
                                description: "Show the cached overview panel from anywhere.",
                                recorder: { KeyboardShortcuts.Recorder(for: .openOverview) }
                            )
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - CLI

    private var cliTab: some View {
        ZStack {
            SettingsUI.settingsBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSectionCard(title: "Command Line", symbol: "terminal") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                SettingsRowIcon(symbol: "hammer")

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text("GhostTile CLI")
                                            .font(.system(size: 13, weight: .semibold))
                                        StatusPill(text: viewModel.cliStatusText, color: viewModel.cliStatusColor)
                                    }

                                    switch viewModel.cliStatus {
                                    case .checking:
                                        Text("Checking current installation status.")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    case .installed:
                                        Text("Installed at \(CLIPaths.installedCLI) with support files.")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    case let .updateAvailable(installedVersion):
                                        Text(
                                            "Installed CLI is \(installedVersion). Bundled CLI is \(viewModel.expectedCLIVersion). Reinstall when you want the bundled copy."
                                        )
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    case .notInstalled:
                                        Text("Optional, but needed for some hardened or protected apps.")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    case let .failed(msg):
                                        Text(msg)
                                            .font(.system(size: 11)).foregroundStyle(.red).textSelection(.enabled)
                                    }
                                }

                                Spacer()

                                if case .checking = viewModel.cliStatus {
                                    ProgressView().controlSize(.small)
                                } else {
                                    HStack(spacing: 8) {
                                        if case .installed = viewModel.cliStatus {
                                            Button("Uninstall") { viewModel.uninstallCLI() }
                                                .controlSize(.small)
                                        }
                                        Button(viewModel.cliActionTitle) { viewModel.installCLI() }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                    }
                                }
                            }

                            if case .failed = viewModel.cliStatus {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Manual recovery")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("Use Reinstall CLI to restore the bundled support files.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.primary.opacity(0.04))
                                )
                            }

                            Divider().padding(.leading, 42)

                            SettingsUI.infoRow(
                                title: "Log",
                                value: viewModel.displayLogPath,
                                symbol: "doc.text"
                            )
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2, perform: viewModel.openLogInConsole)
                            .help("Double-click to open the current log in Console")
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Permissions

    private var permissionsTab: some View {
        ZStack {
            SettingsUI.settingsBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSectionCard(title: "Permissions", symbol: "lock.shield") {
                        PermissionsView()
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - About

    private var aboutTab: some View {
        ZStack {
            SettingsUI.settingsBackground.ignoresSafeArea()

            AboutView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
