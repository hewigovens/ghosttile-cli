import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isComplete: Bool

    @State var step = 0
    @State var iconFlipped = false
    @State var iconScale: CGFloat = 0.78
    @State var iconOpacity = 0.0
    @State var iconLoopTask: Task<Void, Never>?

    let totalSteps = 3
    var isDarkMode: Bool { colorScheme == .dark }

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
}
