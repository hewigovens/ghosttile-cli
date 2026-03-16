import AppKit
import GhostTileCore
import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isComplete: Bool

    @State private var step = 0
    @State private var iconFlipped = false
    @State private var iconScale: CGFloat = 0.78
    @State private var iconOpacity = 0.0
    @State private var iconLoopTask: Task<Void, Never>?

    private let totalSteps = 3
    private var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 14) {
                topBar

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: workflowStep
                    case 2: permissionsStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                footer
            }
            .padding(24)
        }
        .frame(width: 620, height: 520)
        .background(OnboardingWindowCenterer())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.76).delay(0.12)) {
                iconScale = 1
                iconOpacity = 1
            }
            startIconLoop()
        }
        .onDisappear {
            iconLoopTask?.cancel()
            iconLoopTask = nil
        }
    }

    private var topBar: some View {
        HStack {
            Text("Step \(step + 1) of \(totalSteps)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                onboardingPill(title: "Native", systemImage: "sparkles")
                onboardingPill(title: "Menu Bar", systemImage: "menubar.rectangle")
                onboardingPill(title: "CLI", systemImage: "terminal")
            }
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.accentColor : indicatorFill)
                        .frame(width: index == step ? 20 : 6, height: 6)
                }
            }

            Spacer()

            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        step -= 1
                    }
                }
                .buttonStyle(.bordered)
            }

            if step < totalSteps - 1 {
                Button("Continue") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        step += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    UserDefaults.standard.set(true, forKey: "onboardingComplete")
                    withAnimation {
                        isComplete = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var welcomeStep: some View {
        onboardingPanel {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(heroTileFill)
                            .frame(width: 148, height: 148)

                        Group {
                            if iconFlipped {
                                newIcon
                                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                            } else {
                                oldIcon
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("GhostTile 2 keeps the idea, but drops the old baggage.")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("The rewrite focuses on a cleaner control surface, modern automation, and a better hidden-app overview.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    FeatureCard(
                        title: "Managed Set",
                        subtitle: "Build a stable hidden app collection.",
                        systemImage: "eye.slash"
                    )
                    FeatureCard(
                        title: "Overview",
                        subtitle: "Jump back into hidden apps fast.",
                        systemImage: "square.grid.2x2"
                    )
                    FeatureCard(
                        title: "CLI",
                        subtitle: "Automate workflows without URL schemes.",
                        systemImage: "terminal"
                    )
                }
            }
        }
    }

    private var workflowStep: some View {
        onboardingPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text("How it works")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                VStack(spacing: 12) {
                    WorkflowCard(
                        step: "1",
                        title: "Add an app",
                        subtitle: "Use the + button, drag from Finder, or manage it from the CLI.",
                        systemImage: "plus.circle.fill",
                        tint: .blue
                    )
                    WorkflowCard(
                        step: "2",
                        title: "GhostTile hides it from the Dock",
                        subtitle: "The app stays manageable, and you can still reveal or relaunch it later.",
                        systemImage: "eye.slash.fill",
                        tint: .orange
                    )
                    WorkflowCard(
                        step: "3",
                        title: "Bring it back when you need it",
                        subtitle: "Use the main window, Overview, menu bar, or global shortcuts to reactivate it.",
                        systemImage: "arrow.up.forward.app.fill",
                        tint: .green
                    )
                }
            }
        }
    }

    private var permissionsStep: some View {
        onboardingPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Permissions")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("GhostTile needs App Management to prepare apps safely. Terminal helps with protected apps, and Screen & System Audio Recording enables live Overview previews.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    PermissionCard(
                        title: "GhostTile",
                        subtitle: "Needed to prepare apps for hiding and restoration.",
                        systemImage: "eye.slash.circle.fill",
                        tint: .blue
                    )
                    PermissionCard(
                        title: "Terminal",
                        subtitle: "Needed when a protected app must be handled with `sudo ghosttile …`.",
                        systemImage: "terminal.fill",
                        tint: .purple,
                        actionTitle: "Grant",
                        action: openAppManagementSettings
                    )
                    PermissionCard(
                        title: "Screen & System Audio Recording",
                        subtitle: "Lets Overview capture live window thumbnails for managed apps.",
                        systemImage: "rectangle.on.rectangle",
                        tint: .orange,
                        actionTitle: "Grant",
                        action: openScreenCaptureSettings
                    )
                }
            }
        }
    }

    private func onboardingPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(panelStroke, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(isDarkMode ? 0.12 : 0.05), radius: 24, y: 10)
    }

    private var onboardingBackground: some View {
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
                .frame(width: 420, height: 420)
                .blur(radius: 100)
                .offset(x: -220, y: -200)

            Circle()
                .fill(Color.orange.opacity(isDarkMode ? 0.08 : 0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 230, y: 220)

            oldGhostTileWatermark
                .frame(width: 110, height: 110)
                .opacity(isDarkMode ? 0.08 : 0.06)
                .rotationEffect(.degrees(-10))
                .offset(x: 225, y: 185)
        }
        .ignoresSafeArea()
    }

    private var panelFill: Color {
        isDarkMode ? Color.black.opacity(0.18) : Color.white.opacity(0.56)
    }

    private var panelStroke: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var indicatorFill: Color {
        isDarkMode ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    private var heroTileFill: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.74)
    }

    private func onboardingPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
            )
            .overlay(
                Capsule()
                    .stroke(panelStroke, lineWidth: 1)
            )
    }

    private func startIconLoop() {
        iconLoopTask?.cancel()
        iconLoopTask = Task {
            try? await Task.sleep(for: .seconds(0.9))

            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        iconFlipped.toggle()
                    }
                }

                try? await Task.sleep(for: .seconds(1.4))
            }
        }
    }

    private func openAppManagementSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @ViewBuilder
    private var oldIcon: some View {
        let url = resourceURL("appIcon-old.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }

    @ViewBuilder
    private var newIcon: some View {
        let url = resourceURL("appIcon-new.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
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
        BundledResources.resourceURL(named: name)
    }
}
