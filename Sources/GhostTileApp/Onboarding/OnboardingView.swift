import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isComplete: Bool
    @StateObject var viewModel = OnboardingViewModel()

    var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 14) {
                topBar

                Group {
                    switch viewModel.step {
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
                .id(viewModel.step)

                footer
            }
            .padding(24)
        }
        .frame(width: 620, height: 520)
        .background(OnboardingWindowCenterer())
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }
}
