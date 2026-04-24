import SwiftUI

extension OnboardingView {
    var topBar: some View {
        HStack {
            Text("Step \(viewModel.step + 1) of \(viewModel.totalSteps)")
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

    var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0 ..< viewModel.totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == viewModel.step ? Color.accentColor : indicatorFill)
                        .frame(width: index == viewModel.step ? 20 : 6, height: 6)
                }
            }

            Spacer()

            if viewModel.step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.step -= 1
                    }
                }
                .buttonStyle(.bordered)
            }

            if viewModel.step < viewModel.totalSteps - 1 {
                Button("Continue") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.step += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    viewModel.completeOnboarding()
                    withAnimation { isComplete = true }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    var welcomeStep: some View {
        onboardingPanel {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(heroTileFill)
                            .frame(width: 148, height: 148)

                        Group {
                            if viewModel.iconFlipped {
                                newIcon
                                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                            } else {
                                oldIcon
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .scaleEffect(viewModel.iconScale)
                        .opacity(viewModel.iconOpacity)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("GhostTile 2 keeps the idea, but drops the old baggage.")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(
                            "The rewrite focuses on a cleaner control surface, modern automation, and a better hidden-app overview."
                        )
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

    var workflowStep: some View {
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

    var permissionsStep: some View {
        onboardingPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Permissions")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(
                    "GhostTile needs App Management to prepare apps safely. Terminal helps with protected apps, and Screen & System Audio Recording enables live Overview previews."
                )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

                PermissionsView()
            }
        }
    }

    func onboardingPanel(@ViewBuilder content: () -> some View) -> some View {
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
}
