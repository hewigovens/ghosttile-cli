import Foundation

public enum Dylib {
    /// Path to the bundled dylib in the app's Resources or next to the CLI binary.
    public static var bundledPath: String? {
        let execURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])

        // App bundle: Contents/MacOS/GhostTile → Contents/Resources/ghosthide.dylib
        let appPath = execURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/ghosthide.dylib").path
        if FileManager.default.fileExists(atPath: appPath) { return appPath }

        // CLI: same directory as the binary
        let cliPath = execURL.deletingLastPathComponent()
            .appendingPathComponent("ghosthide.dylib").path
        if FileManager.default.fileExists(atPath: cliPath) { return cliPath }

        return nil
    }

    /// Returns a usable dylib path — bundled first, falls back to compiling from source.
    public static func ensureDylib() throws -> String {
        if let path = bundledPath { return path }
        return try compile()
    }

    @discardableResult
    public static func compile() throws -> String {
        let outputPath = "\(Config.configDir)/ghosthide.dylib"
        if FileManager.default.fileExists(atPath: outputPath) {
            return outputPath
        }

        try FileManager.default.createDirectory(
            atPath: Config.configDir, withIntermediateDirectories: true)

        // Write source from the bundled .m file or inline fallback
        let sourcePath = "\(Config.configDir)/ghosthide.m"
        let source = Self.source
        try source.write(toFile: sourcePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: sourcePath) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "clang", "-dynamiclib",
            "-arch", "arm64", "-arch", "x86_64",
            "-framework", "Cocoa",
            "-o", outputPath, sourcePath,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8) ?? ""
            throw GhostTileError("Failed to compile dylib:\n\(output)")
        }

        return outputPath
    }

    // Inline source as fallback when the .m file isn't available
    static let source = """
    #import <Cocoa/Cocoa.h>
    #import <objc/runtime.h>

    static IMP _original_setActivationPolicy = NULL;
    static BOOL _ghosthide_active = YES;

    static void _call_original(id self, SEL _cmd, NSApplicationActivationPolicy policy) {
        if (_original_setActivationPolicy) {
            ((void(*)(id, SEL, NSApplicationActivationPolicy))
                _original_setActivationPolicy)(self, _cmd, policy);
        }
    }

    static void _ghosthide_setActivationPolicy(id self, SEL _cmd,
                                                NSApplicationActivationPolicy policy) {
        if (_ghosthide_active) {
            _call_original(self, _cmd, NSApplicationActivationPolicyAccessory);
        } else {
            _call_original(self, _cmd, policy);
        }
    }

    __attribute__((constructor))
    static void ghosthide_load(void) {
        if (getenv("GHOSTHIDE_DISABLE")) return;

        Method m = class_getInstanceMethod([NSApplication class],
                                           @selector(setActivationPolicy:));
        if (m) {
            _original_setActivationPolicy = method_getImplementation(m);
            method_setImplementation(m, (IMP)_ghosthide_setActivationPolicy);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            _call_original([NSApplication sharedApplication],
                           @selector(setActivationPolicy:),
                           NSApplicationActivationPolicyAccessory);

            NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
            NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];

            [nc addObserverForName:[NSString stringWithFormat:@"%@.ghosttile.hide", bundleId]
                object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                    _ghosthide_active = YES;
                    _call_original([NSApplication sharedApplication],
                                   @selector(setActivationPolicy:),
                                   NSApplicationActivationPolicyAccessory);
                }];

            [nc addObserverForName:[NSString stringWithFormat:@"%@.ghosttile.show", bundleId]
                object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                    _ghosthide_active = NO;
                    _call_original([NSApplication sharedApplication],
                                   @selector(setActivationPolicy:),
                                   NSApplicationActivationPolicyRegular);
                }];

            [nc addObserverForName:[NSString stringWithFormat:@"%@.ghosttile.toggle", bundleId]
                object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                    _ghosthide_active = !_ghosthide_active;
                    _call_original([NSApplication sharedApplication],
                                   @selector(setActivationPolicy:),
                                   _ghosthide_active
                                       ? NSApplicationActivationPolicyAccessory
                                       : NSApplicationActivationPolicyRegular);
                }];
        });
    }
    """
}
