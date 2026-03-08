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

        // Listen for show/hide/toggle notifications from GhostTile
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
