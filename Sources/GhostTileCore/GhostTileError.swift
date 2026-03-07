import Foundation

public struct GhostTileError: Error, LocalizedError {
    public var errorDescription: String?
    public init(_ message: String) { self.errorDescription = message }
}
