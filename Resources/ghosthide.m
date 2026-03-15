#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "fishhook.h"

static IMP _original_setActivationPolicy = NULL;
static OSStatus (*_original_TransformProcessType)(const ProcessSerialNumber *psn,
                                                  ProcessApplicationTransformState transformState) = NULL;
static BOOL _ghosthide_active = YES;
static id _ghosthide_badgeObserver = nil;

#if GHOSTHIDE_DEBUG
static void _ghosthide_log(NSString *message) {
    @autoreleasepool {
        NSString *configDir = [NSHomeDirectory() stringByAppendingPathComponent:@".config/ghosttile"];
        [[NSFileManager defaultManager] createDirectoryAtPath:configDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        NSString *logPath = [configDir stringByAppendingPathComponent:@"ghosthide.log"];
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown.bundle";
        NSString *line = [NSString stringWithFormat:@"%@ [%@:%d] %@\n",
                          [[NSDate date] description],
                          bundleId,
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
#else
static void _ghosthide_log(__unused NSString *message) {
}
#endif

@interface GhostTileBadgeObserver : NSObject
@property (nonatomic, copy) NSString *bundleId;
@end

@implementation GhostTileBadgeObserver

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (![keyPath isEqualToString:@"badgeLabel"] || !_ghosthide_active) {
        return;
    }

    NSString *badgeLabel = change[NSKeyValueChangeNewKey];
    if (![badgeLabel isKindOfClass:[NSString class]] || badgeLabel.length == 0) {
        return;
    }

    NSString *notificationName =
        [NSString stringWithFormat:@"%@.ghosttile.attention", self.bundleId];
    _ghosthide_log([NSString stringWithFormat:@"posting attention notification: %@", notificationName]);
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:notificationName
                                                                   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}

@end

static void _ghosthide_setActivationPolicy(id self, SEL _cmd,
                                            NSApplicationActivationPolicy policy) {
    (void)self;
    (void)_cmd;
    _ghosthide_log([NSString stringWithFormat:@"setActivationPolicy intercepted, requested=%ld hidden=%d",
                    (long)policy, _ghosthide_active]);
}

static OSStatus _ghosthide_TransformProcessType(const ProcessSerialNumber *psn,
                                                ProcessApplicationTransformState transformState) {
    (void)psn;
    _ghosthide_log([NSString stringWithFormat:@"TransformProcessType intercepted, requested=%u hidden=%d",
                    (unsigned int)transformState, _ghosthide_active]);
    (void)transformState;
    return noErr;
}

static void _ghosthide_hookTransformProcessType(void) {
    _original_TransformProcessType = dlsym(RTLD_DEFAULT, "TransformProcessType");
    _ghosthide_log([NSString stringWithFormat:@"hooking TransformProcessType, original=%p",
                    _original_TransformProcessType]);
    struct rebinding rebindings[] = {
        {"TransformProcessType", (void *)_ghosthide_TransformProcessType, (void **)&_original_TransformProcessType},
    };
    int result = rebind_symbols(rebindings, 1);
    _ghosthide_log([NSString stringWithFormat:@"rebind_symbols result=%d replaced=%p",
                    result, _original_TransformProcessType]);
}

static void _ghosthide_transformToType(ProcessApplicationTransformState transformState) {
    ProcessSerialNumber psn = {0, kCurrentProcess};
    BOOL needsTransform = YES;
    NSRunningApplication *runningApp = [NSRunningApplication currentApplication];

    if (runningApp.activationPolicy == NSApplicationActivationPolicyAccessory) {
        if (transformState == kProcessTransformToUIElementApplication) {
            needsTransform = NO;
        }
    } else if (transformState == kProcessTransformToForegroundApplication) {
        needsTransform = NO;
    }

    if (!needsTransform) {
        _ghosthide_log([NSString stringWithFormat:@"transformToType skipped, requested=%u",
                        (unsigned int)transformState]);
        return;
    }

    if (_original_TransformProcessType) {
        _ghosthide_log([NSString stringWithFormat:@"calling original TransformProcessType, requested=%u",
                        (unsigned int)transformState]);
        _original_TransformProcessType(&psn, transformState);
        return;
    }

    _ghosthide_log([NSString stringWithFormat:@"calling fallback TransformProcessType symbol, requested=%u",
                    (unsigned int)transformState]);
    TransformProcessType(&psn, transformState);
}

static void _ghosthide_apply_hidden_state(BOOL hidden) {
    _ghosthide_active = hidden;
    _ghosthide_log([NSString stringWithFormat:@"apply_hidden_state hidden=%d", hidden]);
    _ghosthide_transformToType(hidden
                                   ? kProcessTransformToUIElementApplication
                                   : kProcessTransformToForegroundApplication);
}

__attribute__((constructor))
static void ghosthide_load(void) {
    if (getenv("GHOSTHIDE_DISABLE")) return;
    BOOL startVisible = getenv("GHOSTHIDE_START_VISIBLE") != NULL;
    _ghosthide_log(@"ghosthide_load constructor entered");

    Method m = class_getInstanceMethod([NSApplication class],
                                       @selector(setActivationPolicy:));
    if (m) {
        _original_setActivationPolicy = method_getImplementation(m);
        method_setImplementation(m, (IMP)_ghosthide_setActivationPolicy);
        _ghosthide_log([NSString stringWithFormat:@"hooked setActivationPolicy original=%p",
                        _original_setActivationPolicy]);
    }

    _ghosthide_hookTransformProcessType();

    dispatch_async(dispatch_get_main_queue(), ^{
        _ghosthide_log(@"main queue initialization start");
        _ghosthide_apply_hidden_state(!startVisible);

        // Listen for show/hide/toggle notifications from GhostTile
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
        NSDockTile *dockTile = [[NSApplication sharedApplication] dockTile];

        _ghosthide_badgeObserver = [GhostTileBadgeObserver new];
        [_ghosthide_badgeObserver setBundleId:bundleId];
        [dockTile addObserver:_ghosthide_badgeObserver
                   forKeyPath:@"badgeLabel"
                      options:NSKeyValueObservingOptionNew
                      context:nil];

        [nc addObserverForName:[NSString stringWithFormat:@"%@.ghosttile.hide", bundleId]
            object:nil queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {
                _ghosthide_log(@"received hide notification");
                _ghosthide_apply_hidden_state(YES);
            }];

        [nc addObserverForName:[NSString stringWithFormat:@"%@.ghosttile.show", bundleId]
            object:nil queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {
                _ghosthide_log(@"received show notification");
                _ghosthide_apply_hidden_state(NO);
            }];

        [nc addObserverForName:[NSString stringWithFormat:@"%@.ghosttile.toggle", bundleId]
            object:nil queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {
                _ghosthide_log(@"received toggle notification");
                _ghosthide_apply_hidden_state(!_ghosthide_active);
            }];
        _ghosthide_log(@"main queue initialization complete");
    });
}
