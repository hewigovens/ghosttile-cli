# Hidden-App Hook Debugging

## Context

GhostTile originally hid apps by injecting a helper into the target process and blocking the app from promoting itself back into the Dock.

The modern rewrite now loads the helper persistently by:

- patching the managed app binary with `LC_LOAD_DYLIB @rpath/ghosthide.dylib`
- staging the helper at `Contents/Frameworks/ghosthide.dylib`
- re-signing the modified binary and bundle ad hoc

This replaces the earlier `DYLD_INSERT_LIBRARIES`-only launch path and allows normal app launches to keep the helper loaded.

## Useful Release Hooks

These hooks remain in the release helper because they are useful and correspond to real promotion behavior:

- `-[NSApplication setActivationPolicy:]`
- `-[NSApplication activateIgnoringOtherApps:]`
- `TransformProcessType`

GhostTile uses the saved original `TransformProcessType` only for its own explicit show and hide transitions.

## Probes That Were Tested

These hooks were tested during debugging but are not kept in the release helper:

- `-[NSApplication unhide:]`
- `-[NSWindow makeKeyAndOrderFront:]`
- `applicationShouldHandleReopen:hasVisibleWindows:` on Electron's app delegate
- `-[NSRunningApplication activateWithOptions:]`
- `SetFrontProcess`
- `SetFrontProcessWithOptions`

## Legcord Repro

Target app:

- [Legcord source](/Users/hewig/workspace/github/Legcord)
- Electron version `40.6.0`

Relevant Legcord app code:

- [tray.ts](/Users/hewig/workspace/github/Legcord/src/discord/tray.ts)
  - tray click calls `mainWindow.show()`
- [window.ts](/Users/hewig/workspace/github/Legcord/src/discord/window.ts)
  - app `activate` handler calls `app.show()`

Relevant Electron macOS code that was checked:

- `NativeWindowMac::Show()`
  - `activateIgnoringOtherApps:YES`
  - `makeKeyAndOrderFront:nil`
- `Browser::Show()`
  - `unhide:nil`
- `Browser::DockShow()`
  - `TransformProcessType(...Foreground)`
  - `activateWithOptions(...)`

## Test Method

1. Build debug helper:

```bash
GHOSTHIDE_DEBUG=1 just build-cli
```

2. Re-prepare Legcord:

```bash
./.build/release/ghosttile prepare --force /Applications/legcord.app
```

3. Launch Legcord normally:

```bash
open -a /Applications/legcord.app
```

4. Click the Dock icon through UI scripting:

```bash
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Dock"
    click UI element "Legcord" of list 1
  end tell
end tell
APPLESCRIPT
```

5. Inspect:

- activation policy through `NSWorkspace.shared.runningApplications`
- helper log at `~/.config/ghosttile/ghosthide.log`

## Final Legcord Findings

Fresh Dock-click repro on a hidden Legcord process showed:

- `activateIgnoringOtherApps intercepted, flag=1 hidden=1`
- `makeKeyAndOrderFront intercepted, window=Legcord sender=nil hidden=1`

What did not fire on the decisive repro:

- `unhide`
- `activateWithOptions`
- `TransformProcessType`
- `applicationShouldHandleReopen:hasVisibleWindows:`

Even with `activateIgnoringOtherApps:` and `makeKeyAndOrderFront:` blocked in-process, Legcord still flipped from `NSApplicationActivationPolicyAccessory` to `NSApplicationActivationPolicyRegular`.

## Conclusion

For Electron apps like Legcord, Dock activation can still promote the process back to a regular app outside the direct in-process methods we tested.

Practical implication:

- more in-process hooks are unlikely to fully solve Dock-click re-promotion cleanly
- a future "sticky hidden" behavior should be treated as an explicit option that re-applies hidden state after activation
- do not re-add `unhide`, `makeKeyAndOrderFront`, or delegate reopen hooks to release mode without a new confirmed repro that shows they are the decisive enforcement point

## Current Recommendation

- keep the release helper minimal
- preserve debug-only logging infrastructure for future targeted investigations
- add any stronger post-activation enforcement behind a user preference instead of making it the default behavior
