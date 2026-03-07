import GhostTileCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("autoHideOnLaunch") private var autoHideOnLaunch = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = false
    @State private var cliStatus: CLIInstallStatus = .checking

    enum CLIInstallStatus {
        case checking, notInstalled, installed, failed(String)
    }

    private var bundledCLIPath: String? {
        let execURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let path = execURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("ghosttile-cli").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    private let cliInstallPath = "/usr/local/bin/ghosttile"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // General
            VStack(alignment: .leading, spacing: 12) {
                Text("General")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 16) {
                    settingsRow(
                        title: "Show GhostTile in Dock",
                        subtitle: "Display GhostTile icon in the Dock",
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

                    Divider()

                    settingsRow(
                        title: "Auto-hide apps on launch",
                        subtitle: "Re-hide apps that relaunch after update or crash",
                        toggle: $autoHideOnLaunch
                    )

                    Divider()

                    settingsRow(
                        title: "Launch at login",
                        subtitle: "Start GhostTile automatically when you log in",
                        toggle: Binding(
                            get: { launchAtLogin },
                            set: { setLaunchAtLogin($0) }
                        )
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.primary.opacity(0.03))
                )
            }

            // CLI
            VStack(alignment: .leading, spacing: 12) {
                Text("Command Line")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Install CLI tool")
                                .font(.system(size: 13))
                            switch cliStatus {
                            case .checking:
                                Text("Checking…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            case .installed:
                                Text("Installed at \(cliInstallPath)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.green)
                            case .notInstalled:
                                Text("Required for hiding hardened runtime apps")
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
                        if case .installed = cliStatus {
                            Button("Uninstall") { uninstallCLI() }
                                .controlSize(.small)
                        } else if case .checking = cliStatus {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Install") { installCLI() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }

                    if case .failed = cliStatus {
                        Divider()
                        HStack(spacing: 4) {
                            Text("Run manually:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("sudo cp \"\(bundledCLIPath ?? "...")\" \(cliInstallPath)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.primary.opacity(0.03))
                )
            }

            // About
            VStack(alignment: .leading, spacing: 12) {
                Text("About")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Version")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text({
                            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
                            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                            return "\(version) (\(build))"
                        }())
                            .font(.system(size: 12, design: .monospaced))
                    }
                    Divider()
                    HStack {
                        Text("Config")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("~/.config/ghosttile/")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.primary.opacity(0.03))
                )
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 520)
        .onAppear {
            syncLaunchAtLoginState()
            checkCLIInstalled()
        }
    }

    private func settingsRow(title: String, subtitle: String, toggle: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: toggle)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    private func checkCLIInstalled() {
        cliStatus = FileManager.default.fileExists(atPath: cliInstallPath) ? .installed : .notInstalled
    }

    private func uninstallCLI() {
        do {
            try FileManager.default.removeItem(atPath: cliInstallPath)
            cliStatus = .notInstalled
            return
        } catch {
            Log.info("Direct CLI uninstall failed: \(error)")
        }
        do {
            try HelperClient.removeFile(atPath: cliInstallPath)
            cliStatus = .notInstalled
        } catch {
            Log.error("CLI uninstall failed: \(error)")
            cliStatus = .failed("Uninstall failed")
        }
    }

    private func installCLI() {
        guard let src = bundledCLIPath else {
            cliStatus = .failed("CLI binary not found in app bundle")
            return
        }

        // Try direct copy first
        do {
            if FileManager.default.fileExists(atPath: cliInstallPath) {
                try FileManager.default.removeItem(atPath: cliInstallPath)
            }
            try FileManager.default.copyItem(atPath: src, toPath: cliInstallPath)
            cliStatus = .installed
            return
        } catch {
            Log.info("Direct CLI install failed: \(error)")
        }

        // Fall back to admin cp
        do {
            try HelperClient.copyFile(from: src, to: cliInstallPath)
            cliStatus = .installed
        } catch {
            Log.error("CLI install failed: \(error)")
            cliStatus = .failed("Install failed — see manual command below")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
                launchAtLogin = enabled
            } catch {
                launchAtLogin = !enabled
            }
        }
    }

    private func syncLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
