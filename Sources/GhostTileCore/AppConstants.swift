public enum AppConstants {
    public static let bundleIdentifier = "dev.hewig.ghosttile"
    public static let bundleIdentifierDev = "\(bundleIdentifier).dev"
    public static let bundleIdentifiers: Set<String> = [
        bundleIdentifier,
        bundleIdentifierDev,
    ]
    public static let defaultsSuiteLaunchArgument = "--defaults-suite"
}
