#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "fishhook.h"

static IMP _original_setActivationPolicy = NULL;
static IMP _original_activateIgnoringOtherApps = NULL;
static OSStatus (*_original_TransformProcessType)(const ProcessSerialNumber *psn,
                                                  ProcessApplicationTransformState transformState) = NULL;
static BOOL _ghosthide_active = YES;
static id _ghosthide_badgeObserver = nil;
static IMP _original_applicationDockMenu = NULL;

static void _ghosthide_log(NSString *message);
static void _ghosthide_install_debug_hooks(void);
static void _ghosthide_install_dock_menu(void);

@interface GhostTileBadgeObserver : NSObject
@property (nonatomic, copy) NSString *bundleId;
@end

@implementation GhostTileBadgeObserver

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(__unused id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(__unused void *)context {
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

static BOOL _ghosthide_start_visible(void) {
    return getenv("GHOSTHIDE_START_VISIBLE") != NULL;
}

static NSString *_ghosthide_bundle_id(void) {
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown.bundle";
}

static void _ghosthide_swizzle_instance_method(Class cls, SEL selector, IMP replacement, IMP *original, NSString *label) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        _ghosthide_log([NSString stringWithFormat:@"missing method for %@", label]);
        return;
    }

    *original = method_getImplementation(method);
    method_setImplementation(method, replacement);
    _ghosthide_log([NSString stringWithFormat:@"hooked %@ original=%p", label, *original]);
}

static void _ghosthide_observe_notification(NSDistributedNotificationCenter *center,
                                            NSString *bundleId,
                                            NSString *action,
                                            void (^handler)(void)) {
    NSString *name = [NSString stringWithFormat:@"%@.ghosttile.%@", bundleId, action];
    [center addObserverForName:name
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
        _ghosthide_log([NSString stringWithFormat:@"received %@ notification", action]);
        handler();
    }];
}

static void _ghosthide_install_badge_observer(NSString *bundleId) {
    NSDockTile *dockTile = [[NSApplication sharedApplication] dockTile];
    _ghosthide_badgeObserver = [GhostTileBadgeObserver new];
    [_ghosthide_badgeObserver setBundleId:bundleId];
    [dockTile addObserver:_ghosthide_badgeObserver
               forKeyPath:@"badgeLabel"
                  options:NSKeyValueObservingOptionNew
                  context:nil];
}

static void _ghosthide_setActivationPolicy(__unused id self,
                                           __unused SEL _cmd,
                                           NSApplicationActivationPolicy policy) {
    _ghosthide_log([NSString stringWithFormat:@"setActivationPolicy intercepted, requested=%ld hidden=%d",
                    (long)policy, _ghosthide_active]);
}

static void _ghosthide_activateIgnoringOtherApps(id self, SEL _cmd, BOOL flag) {
    _ghosthide_log([NSString stringWithFormat:@"activateIgnoringOtherApps intercepted, flag=%d hidden=%d",
                    flag, _ghosthide_active]);
    if (!_ghosthide_active && _original_activateIgnoringOtherApps) {
        ((void(*)(id, SEL, BOOL))_original_activateIgnoringOtherApps)(self, _cmd, flag);
    }
}

static OSStatus _ghosthide_TransformProcessType(const ProcessSerialNumber *psn,
                                                ProcessApplicationTransformState transformState) {
    (void)psn;
    _ghosthide_log([NSString stringWithFormat:@"TransformProcessType intercepted, requested=%u hidden=%d",
                    (unsigned int)transformState, _ghosthide_active]);
    return noErr;
}

static void _ghosthide_hookTransformProcessType(void) {
    _original_TransformProcessType = dlsym(RTLD_DEFAULT, "TransformProcessType");
    _ghosthide_log([NSString stringWithFormat:@"hooking TransformProcessType, original=%p",
                    _original_TransformProcessType]);

    struct rebinding rebinding = {
        "TransformProcessType",
        (void *)_ghosthide_TransformProcessType,
        (void **)&_original_TransformProcessType
    };
    int result = rebind_symbols(&rebinding, 1);
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

static void _ghosthide_install_core_hooks(void) {
    _ghosthide_swizzle_instance_method([NSApplication class],
                                       @selector(setActivationPolicy:),
                                       (IMP)_ghosthide_setActivationPolicy,
                                       &_original_setActivationPolicy,
                                       @"setActivationPolicy");
    _ghosthide_swizzle_instance_method([NSApplication class],
                                       @selector(activateIgnoringOtherApps:),
                                       (IMP)_ghosthide_activateIgnoringOtherApps,
                                       &_original_activateIgnoringOtherApps,
                                       @"activateIgnoringOtherApps");
    _ghosthide_hookTransformProcessType();
}

static void _ghosthide_configure_notifications(NSString *bundleId) {
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    _ghosthide_install_badge_observer(bundleId);

    _ghosthide_observe_notification(center, bundleId, @"hide", ^{
        _ghosthide_apply_hidden_state(YES);
    });
    _ghosthide_observe_notification(center, bundleId, @"show", ^{
        _ghosthide_apply_hidden_state(NO);
    });
    _ghosthide_observe_notification(center, bundleId, @"toggle", ^{
        _ghosthide_apply_hidden_state(!_ghosthide_active);
    });
}

@interface GhostTileDockMenuHandler : NSObject
+ (void)toggleDockVisibility:(id)sender;
@end

@implementation GhostTileDockMenuHandler

+ (void)toggleDockVisibility:(__unused id)sender {
    _ghosthide_apply_hidden_state(YES);
}

@end

static NSMenu *_ghosthide_applicationDockMenu(id self, SEL _cmd, NSApplication *sender) {
    NSMenu *menu = nil;
    if (_original_applicationDockMenu) {
        menu = ((NSMenu *(*)(id, SEL, NSApplication *))_original_applicationDockMenu)(self, _cmd, sender);
    }
    if (!menu) {
        menu = [[NSMenu alloc] init];
    }

    if (menu.numberOfItems > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
    }

    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Hide from Dock"
                                                 action:@selector(toggleDockVisibility:)
                                          keyEquivalent:@""];
    item.target = [GhostTileDockMenuHandler class];
    [menu addItem:item];
    return menu;
}

static void _ghosthide_install_dock_menu(void) {
    id delegate = [[NSApplication sharedApplication] delegate];
    if (!delegate) {
        _ghosthide_log(@"no app delegate, skipping dock menu install");
        return;
    }

    Class delegateClass = [delegate class];
    SEL sel = @selector(applicationDockMenu:);

    if (class_getInstanceMethod(delegateClass, sel)) {
        _ghosthide_swizzle_instance_method(delegateClass, sel,
                                           (IMP)_ghosthide_applicationDockMenu,
                                           &_original_applicationDockMenu,
                                           @"applicationDockMenu");
    } else {
        class_addMethod(delegateClass, sel,
                        (IMP)_ghosthide_applicationDockMenu, "@@:@");
        _ghosthide_log(@"added applicationDockMenu: to delegate");
    }
}

__attribute__((constructor))
static void ghosthide_load(void) {
    if (getenv("GHOSTHIDE_DISABLE")) {
        return;
    }

    _ghosthide_log(@"ghosthide_load constructor entered");
    _ghosthide_install_core_hooks();
    _ghosthide_install_debug_hooks();

    dispatch_async(dispatch_get_main_queue(), ^{
        _ghosthide_log(@"main queue initialization start");
        _ghosthide_apply_hidden_state(!_ghosthide_start_visible());
        _ghosthide_configure_notifications(_ghosthide_bundle_id());
        _ghosthide_install_dock_menu();
        _ghosthide_log(@"main queue initialization complete");
    });
}

#if GHOSTHIDE_DEBUG
static void _ghosthide_log(NSString *message) {
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

static void _ghosthide_install_debug_hooks(void) {
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
static void _ghosthide_log(__unused NSString *message) {
}

static void _ghosthide_install_debug_hooks(void) {
}
#endif
