import Foundation

public enum GhostTileError: Error, LocalizedError {
    case generic(String)
    case appManagementDenied(path: String)

    public init(_ message: String) {
        self = .generic(message)
    }

    public var errorDescription: String? {
        switch self {
        case let .generic(message):
            message
        case let .appManagementDenied(path):
            "macOS App Management denied access to \(path)."
                + " Grant GhostTile access in System Settings → Privacy & Security → App Management,"
                + " then quit and relaunch."
        }
    }

    public static func isAppManagementDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(EPERM) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           underlying.code == Int(EPERM)
        {
            return true
        }
        return false
    }
}
