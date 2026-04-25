import AppKit
import Foundation

@MainActor
final class SponsorNudgeController: ObservableObject {
    static let shared = SponsorNudgeController()

    @Published var isPresented = false

    private enum Keys {
        static let usageCount = "sponsorNudgeUsageCount"
        static let promptCount = "sponsorNudgePromptCount"
        static let lastPromptAt = "sponsorNudgeLastPromptAt"
        static let optedOut = "sponsorNudgeOptedOut"
        static let completed = "sponsorNudgeCompleted"
    }

    private let defaults = UserDefaults.standard
    private let firstPromptUsageThreshold = 6
    private let repeatPromptUsageInterval = 15
    private let remindCooldown: TimeInterval = 60 * 60 * 24 * 14
    // swiftlint:disable:next force_unwrapping
    private let sponsorsURL = URL(string: "https://github.com/sponsors/hewigovens")!

    private init() {}

    func recordMeaningfulUse() {
        guard !defaults.bool(forKey: Keys.optedOut),
              !defaults.bool(forKey: Keys.completed)
        else { return }

        defaults.set(defaults.integer(forKey: Keys.usageCount) + 1, forKey: Keys.usageCount)

        let hasVisibleMainWindow = NSApp.windows.contains {
            ($0.identifier?.rawValue.contains("main") == true || $0.title == "GhostTile") && $0.isVisible
        }
        if hasVisibleMainWindow {
            considerPrompt()
        }
    }

    func considerPrompt() {
        guard !isPresented,
              !defaults.bool(forKey: Keys.optedOut),
              !defaults.bool(forKey: Keys.completed)
        else { return }

        let usageCount = defaults.integer(forKey: Keys.usageCount)
        let promptCount = defaults.integer(forKey: Keys.promptCount)
        let nextUsageThreshold = firstPromptUsageThreshold + (promptCount * repeatPromptUsageInterval)

        guard usageCount >= nextUsageThreshold else { return }

        if let lastPromptAt = defaults.object(forKey: Keys.lastPromptAt) as? Date,
           Date().timeIntervalSince(lastPromptAt) < remindCooldown
        {
            return
        }

        defaults.set(promptCount + 1, forKey: Keys.promptCount)
        defaults.set(Date(), forKey: Keys.lastPromptAt)
        isPresented = true
    }

    func presentForTesting() {
        isPresented = true
    }

    func remindLater() {
        isPresented = false
    }

    func stopPrompting() {
        defaults.set(true, forKey: Keys.optedOut)
        isPresented = false
    }

    func openSponsorsPage() {
        defaults.set(true, forKey: Keys.completed)
        isPresented = false
        NSWorkspace.shared.open(sponsorsURL)
    }
}
