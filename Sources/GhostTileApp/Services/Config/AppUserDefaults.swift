import Foundation
import GhostTileCore

enum AppUserDefaults {
    static let store: UserDefaults = {
        let arguments = CommandLine.arguments
        guard let argumentIndex = arguments.firstIndex(of: AppConstants.defaultsSuiteLaunchArgument) else {
            return .standard
        }

        let suiteNameIndex = arguments.index(after: argumentIndex)
        guard arguments.indices.contains(suiteNameIndex),
              let store = UserDefaults(suiteName: arguments[suiteNameIndex])
        else {
            return .standard
        }

        return store
    }()
}
