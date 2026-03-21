#import "ghosthide.h"

#if GHOSTHIDE_DEBUG

void _ghosthide_log(NSString *message) {
    @autoreleasepool {
        NSString *configDir = [NSHomeDirectory() stringByAppendingPathComponent:@".config/ghosttile"];
        [[NSFileManager defaultManager] createDirectoryAtPath:configDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        NSString *logPath = [configDir stringByAppendingPathComponent:@"ghosthide.log"];
        NSString *line = [NSString stringWithFormat:@"%@ [%@:%d] %@\n",
                          [[NSDate date] description],
                          _ghosthide_bundle_id(),
                          getpid(),
                          message];
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
        if (!handle) {
            [line writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            return;
        }
        @try {
            [handle seekToEndOfFile];
            [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
        @catch (__unused NSException *exception) {
        }
    }
}

static IMP _original_makeKeyAndOrderFront = NULL;
static IMP _original_runningApplicationActivateWithOptions = NULL;

static void _ghosthide_makeKeyAndOrderFront(id self, SEL _cmd, id sender) {
    NSString *windowTitle = nil;
    if ([self respondsToSelector:@selector(title)]) {
        windowTitle = [self performSelector:@selector(title)];
    }
    _ghosthide_log([NSString stringWithFormat:@"makeKeyAndOrderFront intercepted, window=%@ sender=%@ hidden=%d",
                    windowTitle.length > 0 ? windowTitle : @"untitled",
                    sender ? NSStringFromClass([sender class]) : @"nil",
                    _ghosthide_active]);
    if (!_ghosthide_active && _original_makeKeyAndOrderFront) {
        ((void(*)(id, SEL, id))_original_makeKeyAndOrderFront)(self, _cmd, sender);
    }
}

static BOOL _ghosthide_runningApplicationActivateWithOptions(id self, SEL _cmd, NSApplicationActivationOptions options) {
    NSString *bundleId = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleId = [self performSelector:@selector(bundleIdentifier)];
    }
    _ghosthide_log([NSString stringWithFormat:@"NSRunningApplication activateWithOptions intercepted, bundle=%@ options=%lu hidden=%d",
                    bundleId ?: @"unknown",
                    (unsigned long)options,
                    _ghosthide_active]);
    if (_original_runningApplicationActivateWithOptions) {
        return ((BOOL(*)(id, SEL, NSApplicationActivationOptions))
                _original_runningApplicationActivateWithOptions)(self, _cmd, options);
    }
    return NO;
}

void _ghosthide_install_debug_hooks(void) {
    _ghosthide_swizzle_instance_method([NSWindow class],
                                       @selector(makeKeyAndOrderFront:),
                                       (IMP)_ghosthide_makeKeyAndOrderFront,
                                       &_original_makeKeyAndOrderFront,
                                       @"makeKeyAndOrderFront");
    _ghosthide_swizzle_instance_method([NSRunningApplication class],
                                       @selector(activateWithOptions:),
                                       (IMP)_ghosthide_runningApplicationActivateWithOptions,
                                       &_original_runningApplicationActivateWithOptions,
                                       @"NSRunningApplication activateWithOptions");
}

#else

void _ghosthide_log(__unused NSString *message) {
}

void _ghosthide_install_debug_hooks(void) {
}

#endif
