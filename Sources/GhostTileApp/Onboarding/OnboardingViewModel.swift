import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    @Published var iconFlipped = false
    @Published var iconScale: CGFloat = 0.78
    @Published var iconOpacity = 0.0

    let totalSteps = 3
    private static let iconLoopInitialDelay: Duration = .seconds(1.1)
    private static let iconFlipDuration = 0.8
    private static let iconFlipInterval: Duration = .seconds(1.8)
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

    private func startIconLoop() {
        iconLoopTask?.cancel()
        iconLoopTask = Task {
            try? await Task.sleep(for: Self.iconLoopInitialDelay)
            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: Self.iconFlipDuration)) {
                        iconFlipped.toggle()
                    }
                }
                try? await Task.sleep(for: Self.iconFlipInterval)
            }
        }
    }
}
