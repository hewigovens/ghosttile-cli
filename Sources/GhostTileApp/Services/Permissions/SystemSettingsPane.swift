import Foundation

enum SystemSettingsPane {
    case appManagement
    case screenRecording

    var title: String {
        switch self {
        case .appManagement:
            "App Management"
        case .screenRecording:
            "Screen & System Audio Recording"
        }
    }

    var settingsURL: URL {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(privacyAnchor)") else {
            preconditionFailure("Invalid System Settings URL for \(privacyAnchor)")
        }
        return url
    }

    private var privacyAnchor: String {
        switch self {
        case .appManagement:
            "Privacy_AppBundles"
        case .screenRecording:
            "Privacy_ScreenCapture"
        }
    }
}
