import AppKit
import GhostTileCore
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("autoHideOnLaunch") var autoHideOnLaunch = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showInDock") var showInDock = false
    @State var cliStatus: CLIInstallStatus = .checking
    @State var versionTapCount = 0
    @State var lastVersionTapAt = Date.distantPast

    enum CLIInstallStatus {
        case checking, notInstalled, installed, failed(String)
    }

    let cliInstallPath = "/usr/local/bin/ghosttile"
    let cliDylibInstallPath = "/usr/local/bin/ghosthide.dylib"
    let expectedCLIVersion = BuildInfo.displayVersion

    var body: some View {
        ZStack {
            settingsBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionCard(
                        title: "General",
                        symbol: "slider.horizontal.3"
                    ) {
                        VStack(spacing: 0) {
                            settingsRow(
                                title: "Show GhostTile in Dock",
                                symbol: "dock.rectangle",
                                toggle: Binding(
                                    get: { showInDock },
                                    set: { newValue in
                                        showInDock = newValue
                                        if newValue {
                                            NSApp.setActivationPolicy(.regular)
                                            NSApp.activate(ignoringOtherApps: true)
                                        } else {
                                            NSApp.setActivationPolicy(.accessory)
                                        }
                                    }
                                )
                            )

                            Divider().padding(.leading, 42)

                            settingsRow(
                                title: "Auto-hide apps on launch",
                                symbol: "arrow.triangle.2.circlepath",
                                toggle: $autoHideOnLaunch
                            )

                            Divider().padding(.leading, 42)

                            settingsRow(
                                title: "Launch at login",
                                symbol: "power.circle",
                                toggle: Binding(
                                    get: { launchAtLogin },
                                    set: { setLaunchAtLogin($0) }
                                )
                            )
                        }
                    }

                    sectionCard(
                        title: "Shortcuts",
                        symbol: "command"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            shortcutRow(
                                title: "Open Main Window",
                                symbol: "macwindow",
                                description: "Bring GhostTile's main workspace forward from anywhere.",
                                recorder: {
                                    KeyboardShortcuts.Recorder(for: .openMainWindow)
                                }
                            )

                            shortcutRow(
                                title: "Open Overview",
                                symbol: "square.grid.2x2",
                                description: "Show the cached overview panel from anywhere.",
                                recorder: {
                                    KeyboardShortcuts.Recorder(for: .openOverview)
                                }
                            )
                        }
                    }

                    sectionCard(
                        title: "Command Line",
                        symbol: "terminal"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text("GhostTile CLI")
                                            .font(.system(size: 13, weight: .semibold))
                                        statusPill(text: cliStatusText, color: cliStatusColor)
                                    }

                                    switch cliStatus {
                                    case .checking:
                                        Text("Checking current installation status.")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    case .installed:
                                        Text("Installed at \(cliInstallPath) with support files.")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    case .notInstalled:
                                        Text("Optional, but needed for some hardened or protected apps.")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    case .failed(let msg):
                                        Text(msg)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.red)
                                            .textSelection(.enabled)
                                    }
                                }

                                Spacer()

                                if case .checking = cliStatus {
                                    ProgressView().controlSize(.small)
                                } else {
                                    HStack(spacing: 8) {
                                        if case .installed = cliStatus {
                                            Button("Uninstall") { uninstallCLI() }
                                                .controlSize(.small)
                                        }

                                        Button(cliActionTitle) { installCLI() }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                    }
                                }
                            }

                            if case .failed = cliStatus {
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

                            infoRow(
                                title: "Log",
                                value: displayLogPath,
                                symbol: nil
                            )
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2, perform: openLogInConsole)
                            .help("Double-click to open the current log in Console")
                        }
                    }

                    sectionCard(
                        title: "About",
                        symbol: "info.circle"
                    ) {
                        VStack(spacing: 0) {
                            infoRow(
                                title: "Version",
                                value: {
                                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? BuildInfo.version
                                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? BuildInfo.build
                                    return "\(version) (\(build))"
                                }(),
                                symbol: "shippingbox"
                            )
                            .contentShape(Rectangle())
                            .onTapGesture(perform: handleVersionTap)

                            Divider().padding(.leading, 42)

                            actionRow(
                                title: "Sponsor on GitHub",
                                value: "",
                                symbol: "heart",
                                action: {
                                    SponsorNudgeController.shared.openSponsorsPage()
                                }
                            )
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 560, height: 700)
        .onAppear {
            syncLaunchAtLoginState()
            checkCLIInstalled()
        }
    }
}
