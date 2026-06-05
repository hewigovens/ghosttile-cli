import Foundation

/// Whether a binary has GhostTile's ghosthide load command, cached by file identity (size + mtime).
public enum GhosthidePatch {
    private struct Entry {
        let size: Int
        let modified: TimeInterval
        let isApplied: Bool
    }

    private static let lock = NSLock()
    private static var entries: [String: Entry] = [:]

    public static func isApplied(to binaryPath: String) -> Bool {
        let identity = fileIdentity(binaryPath)

        if let identity {
            lock.lock()
            let cached = entries[binaryPath]
            lock.unlock()
            if let cached, cached.size == identity.size, cached.modified == identity.modified {
                return cached.isApplied
            }
        }

        let isApplied = (try? MachOEditor.hasGhosthideLoadCommand(in: binaryPath)) ?? false

        if let identity {
            lock.lock()
            entries[binaryPath] = Entry(size: identity.size, modified: identity.modified, isApplied: isApplied)
            lock.unlock()
        }

        return isApplied
    }

    private static func fileIdentity(_ path: String) -> (size: Int, modified: TimeInterval)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int,
              let modified = attributes[.modificationDate] as? Date
        else { return nil }
        return (size, modified.timeIntervalSinceReferenceDate)
    }
}
