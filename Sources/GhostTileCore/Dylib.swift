import Foundation

public enum Dylib {
    public static var dylibPath: String {
        "\(Config.configDir)/ghosthide.dylib"
    }

    public static let source = """
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

            // Listen for toggle notification from GhostTile
            NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
            NSString *toggleName = [NSString stringWithFormat:@"%@.ghosttile.toggle", bundleId];
            [[NSDistributedNotificationCenter defaultCenter]
                addObserverForName:toggleName object:nil
                queue:[NSOperationQueue mainQueue]
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

    public static func ensureCompiled() throws -> String {
        if FileManager.default.fileExists(atPath: dylibPath) {
            return dylibPath
        }
        return try compile()
    }

    @discardableResult
    public static func compile() throws -> String {
        try FileManager.default.createDirectory(
            atPath: Config.configDir, withIntermediateDirectories: true)

        let sourcePath = "\(Config.configDir)/ghosthide.m"
        try source.write(toFile: sourcePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: sourcePath) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "clang", "-dynamiclib",
            "-arch", "arm64", "-arch", "x86_64",
            "-framework", "Cocoa",
            "-o", dylibPath, sourcePath,
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

        return dylibPath
    }
}
