import AppKit
import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var step = 0
    @State private var iconFlipped = false
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0

    private let totalSteps = 2

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: howItWorksStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(step)

            Divider()

            // Navigation
            HStack {
                // Step indicators
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                if step > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                if step < totalSteps - 1 {
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        withAnimation {
                            isComplete = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    iconFlipped = true
                }
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon animation: old → new
            ZStack {
                if !iconFlipped {
                    oldIcon
                        .transition(.opacity)
                } else {
                    newIcon
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(width: 120, height: 120)
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            VStack(spacing: 8) {
                Text("Welcome to GhostTile 2.0")
                    .font(.system(size: 22, weight: .bold))

                Text("A complete rewrite — modern, fast, and native.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // What's new pills
            HStack(spacing: 10) {
                FeaturePill(icon: "swift", text: "SwiftUI")
                FeaturePill(icon: "menubar.rectangle", text: "Menu Bar")
                FeaturePill(icon: "arrow.triangle.2.circlepath", text: "Auto-hide")
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 2: How It Works

    private var howItWorksStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How It Works")
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 16) {
                StepRow(
                    number: 1,
                    icon: "plus.circle.fill",
                    color: .blue,
                    title: "Add an app",
                    subtitle: "Pick from running apps or drag from Finder"
                )
                StepRow(
                    number: 2,
                    icon: "eye.slash.fill",
                    color: .purple,
                    title: "App hides from Dock & Cmd+Tab",
                    subtitle: "Re-signed with lightweight injection"
                )
                StepRow(
                    number: 3,
                    icon: "arrow.clockwise.circle.fill",
                    color: .green,
                    title: "Stays hidden automatically",
                    subtitle: "Survives relaunches, updates, and reboots"
                )
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var oldIcon: some View {
        let url = resourceURL("appIcon-old.png")
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
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
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }

    private func resourceURL(_ name: String) -> URL {
        let execURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        return execURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent(name)
    }

}

// MARK: - Supporting Views

struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.1))
        )
        .foregroundColor(.accentColor)
    }
}

struct StepRow: View {
    let number: Int
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
