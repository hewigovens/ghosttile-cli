import AppKit
import GhostTileCore
import KeyboardShortcuts
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
    private var displayLogPath: String {
        (Log.logPath as NSString).abbreviatingWithTildeInPath
    }
    private var cliStatusText: String {
        switch cliStatus {
        case .checking:
            return "Checking"
        case .installed:
            return "Installed"
        case .notInstalled:
            return "Optional"
        case .failed:
            return "Needs Attention"
        }
    }
    private var cliStatusColor: Color {
        switch cliStatus {
        case .checking:
            return .secondary
        case .installed:
            return .green
        case .notInstalled:
            return .orange
        case .failed:
            return .red
        }
    }

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
                                        Text("Installed at \(cliInstallPath)")
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
                                    Text("Manual install")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("sudo cp \"\(bundledCLIPath ?? "...")\" \(cliInstallPath)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.primary.opacity(0.04))
                                )
                            }
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
                                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
                                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                                    return "\(version) (\(build))"
                                }(),
                                symbol: "shippingbox"
                            )

                            Divider().padding(.leading, 42)

                            infoRow(
                                title: "Log",
                                value: displayLogPath,
                                symbol: "doc.text.magnifyingglass"
                            )
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2, perform: openLogInConsole)
                            .help("Double-click to open the current log in Console")
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

    private var settingsBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.06),
                    Color.clear,
                    Color.green.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.05))
                .frame(width: 240, height: 240)
                .blur(radius: 55)
                .offset(x: -170, y: -180)

            Circle()
                .fill(Color.orange.opacity(0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 55)
                .offset(x: 170, y: 180)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }

    private func settingsRow(
        title: String,
        symbol: String,
        toggle: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
            Toggle("", isOn: toggle)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    private func shortcutRow<Recorder: View>(
        title: String,
        symbol: String,
        description: String,
        @ViewBuilder recorder: () -> Recorder
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            recorder()
                .labelsHidden()
        }
    }

    private func infoRow(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }

            Spacer()

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }

    private func checkCLIInstalled() {
        cliStatus = FileManager.default.fileExists(atPath: cliInstallPath) ? .installed : .notInstalled
    }

    private var cliActionTitle: String {
        switch cliStatus {
        case .installed:
            return "Reinstall CLI"
        case .checking, .notInstalled, .failed:
            return "Install CLI"
        }
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

    private func openLogInConsole() {
        if !FileManager.default.fileExists(atPath: Log.logPath) {
            FileManager.default.createFile(atPath: Log.logPath, contents: Data())
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Console", Log.logPath]

        do {
            try process.run()
        } catch {
            Log.error("Failed to open log in Console: \(error)")
        }
    }
}
