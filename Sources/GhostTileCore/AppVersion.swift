import Foundation

public struct AppVersion: Codable, Equatable, Sendable {
    public let shortVersion: String?
    public let build: String?

    public init(shortVersion: String? = nil, build: String? = nil) {
        self.shortVersion = Self.normalized(shortVersion)
        self.build = Self.normalized(build)
    }

    public init?(bundle: Bundle) {
        self.init(
            shortVersion: Self.infoValue(
                bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            ),
            build: Self.infoValue(bundle.object(forInfoDictionaryKey: "CFBundleVersion"))
        )

        if shortVersion == nil, build == nil {
            return nil
        }
    }

    public var displayString: String {
        switch (shortVersion, build) {
        case let (shortVersion?, build?):
            "\(shortVersion) (\(build))"
        case let (shortVersion?, nil):
            shortVersion
        case let (nil, build?):
            "build \(build)"
        case (nil, nil):
            "unknown"
        }
    }

    private static func infoValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return normalized(string)
        }

        if let number = value as? NSNumber {
            return normalized(number.stringValue)
        }

        return nil
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
