#import <Cocoa/Cocoa.h>

@interface TestAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation TestAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *sentinelPath = [NSProcessInfo processInfo].environment[@"GHOSTTILE_TEST_SENTINEL"];
    if (sentinelPath) {
        [@"launched" writeToFile:sentinelPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [NSApp terminate:nil];
    });
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        TestAppDelegate *delegate = [[TestAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
