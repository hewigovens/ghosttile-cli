#pragma once
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <objc/runtime.h>

extern BOOL _ghosthide_active;

extern void _ghosthide_log(NSString *message);
extern NSString *_ghosthide_bundle_id(void);
extern void _ghosthide_swizzle_instance_method(Class cls, SEL selector, IMP replacement, IMP *original, NSString *label);
extern void _ghosthide_apply_hidden_state(BOOL hidden);
extern void _ghosthide_install_debug_hooks(void);
