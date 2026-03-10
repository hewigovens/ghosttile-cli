# GhostTile Migration Plan

## Goals

- Keep the CLI as the canonical automation surface on modern macOS.
- Restore the highest-value legacy workflows that still make sense.
- Avoid reviving features that are obsolete, fragile, or redundant with the CLI.

## Out of Scope

- URL schemes
- Alfred-specific integrations
- Legacy quick-switch palette
- Target mode
- Sounds
- Touch Bar support
- Licensing, analytics, and legacy update plumbing

## Phase 1: CLI as the Primary Automation Layer

### Objectives

- Let `ghosttile manage` accept app bundle paths in addition to running app names and bundle IDs.
- Make CLI actions work cleanly for apps that are not already running.
- Improve modern macOS error handling around SIP, permissions, and `sudo` fallback.

### Tasks

- Add a shared resolver in `GhostTileCore` that:
  - detects bundle path input such as `/Applications/Foo.app`
  - loads bundle metadata directly from disk
  - falls back to the existing running-app lookup by name or bundle ID
- Update the CLI commands to use the shared resolver consistently.
- Improve CLI messages for:
  - invalid app bundles
  - SIP-protected apps
  - apps that require preparation
  - apps that require manual `sudo` fallback
- Decide whether `focus` should also launch a non-running managed app, or whether that should be a separate command.
- Update the README with the new CLI behavior and examples.

### Files

- `Sources/GhostTileCore/AppManager.swift`
- `Sources/ghosttile/Commands.swift`
- `Sources/ghosttile/GhostTile.swift`
- `README.md`

### Success Criteria

- A user can manage an app by path without relying on a launcher integration.
- The CLI is sufficient as the automation foundation for a future Raycast extension.

## Phase 2: Status Bar as a Control Surface

### Objectives

- Turn the status bar menu into a full control surface for managed apps.
- Reduce the need to open the main window for common actions.

### Tasks

- Expand each managed app menu entry to support:
  - activate
  - show in Dock
  - hide from Dock
  - reveal in Finder
  - remove from management
- Disable or adapt actions when the app is not currently running.
- Keep the action logic in the view model so the status bar and main window share behavior.
- Ensure the menu reflects the current running/hidden state accurately.

### Files

- `Sources/GhostTileApp/StatusBarController.swift`
- `Sources/GhostTileApp/AppViewModel.swift`
- `Sources/GhostTileApp/MainWindowView.swift` if action parity is needed

### Success Criteria

- Most daily GhostTile interactions can be completed from the menu bar alone.

## Phase 3: Attention Notifications

### Objectives

- Restore lightweight notifications when a hidden managed app needs user attention.
- Keep the behavior simple and modern.

### Tasks

- Define a notification channel for managed apps that request attention while hidden.
- Extend the injected helper behavior so the managed app can emit a distributed notification.
- Observe those notifications in the app and surface a user-facing macOS notification.
- Make clicking the notification activate the app and, if needed, reveal it in the Dock first.
- Keep this feature optional if modern macOS notification behavior requires explicit permission handling.

### Files

- `Sources/GhostTileCore/ManagedAppNotifications.swift`
- `Sources/GhostTileCore/Dylib.swift`
- `Sources/GhostTileApp/AppViewModel.swift`
- `Sources/GhostTileApp/GhostTileApp.swift` if lifecycle hooks are needed

### Success Criteria

- Hidden apps can alert the user without forcing permanent Dock visibility.

## Phase 4: Modern Expose View

### Objectives

- Bring back the Expose-style overview as the visual power-user surface.
- Rebuild it for the modern rewrite instead of porting the old UI literally.

### Tasks

- Design a managed-app overview focused on:
  - search
  - activation
  - show/hide state
  - remove/reveal actions
- Implement it as a SwiftUI-first feature, with AppKit only where necessary for overlay/window behavior.
- Reuse `AppViewModel` data and actions rather than building a separate state model.
- Validate that it still behaves well under the rewrite's modern macOS limitations.

### Files

- New files under `Sources/GhostTileApp`
- `Sources/GhostTileApp/AppViewModel.swift`
- `Sources/GhostTileApp/GhostTileApp.swift`

### Success Criteria

- The app regains a distinctive visual management surface without reintroducing obsolete launcher behavior.

## Later Work

- Global shortcuts for opening the Expose view and other high-value actions.
- Possible Raycast extension built on the CLI once Phase 1 is stable.

## Execution Order

1. CLI path-based management
2. Richer status bar actions
3. Attention notifications
4. Expose view
5. Shortcuts later

## Validation

- Run `swift build` after each implementation phase.
- Run `just build` when packaging or resources change.
- When changing shared app/core behavior, verify at least one GUI flow and one CLI flow conceptually.
