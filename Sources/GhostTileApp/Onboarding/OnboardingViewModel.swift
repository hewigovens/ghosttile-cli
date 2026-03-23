import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    @Published var iconFlipped = false
    @Published var iconScale: CGFloat = 0.78
    @Published var iconOpacity = 0.0

    let totalSteps = 3
    private var iconLoopTask: Task<Void, Never>?

    func onAppear() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.76).delay(0.12)) {
            iconScale = 1
            iconOpacity = 1
        }
        startIconLoop()
    }

    func onDisappear() {
        iconLoopTask?.cancel()
        iconLoopTask = nil
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
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
}
