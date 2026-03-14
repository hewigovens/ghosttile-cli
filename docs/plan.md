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

## Phase 1: CLI as the Primary Automation Layer [Completed]

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

### Implemented

- `ghosttile manage` now accepts app bundle paths in addition to running app names and bundle IDs.
- `ghosttile list --json` and `ghosttile status --json` now expose stable machine-readable output.
- The README was updated with the new CLI usage and JSON integration path.

## Phase 2: Status Bar as a Control Surface [Completed]

### Objectives

- Turn the status bar menu into a full control surface for managed apps.
- Reduce the need to open the main window for common actions.

### Tasks

- Expand each managed app menu entry to support:
  - activate or launch
  - show in Dock
  - hide from Dock
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

### Implemented

- The status bar now exposes per-app actions for activate or launch, show in Dock, hide from Dock, and remove from management.
- Shared action handling now lives in the app view model instead of being duplicated in the menu controller.
- The menu now mirrors recorded global shortcuts for `Show Main Window` and `Show Overview`.
- Settings opens from the status bar in a persistent centered window.

## Phase 2.5: Raycast Extension [Completed]

### Objectives

- Add a launcher integration without reviving URL schemes or duplicating GhostTile logic outside the CLI.

### Tasks

- Scaffold a local Raycast extension that shells out to `ghosttile`.
- Use `ghosttile list --json` and `ghosttile status --json` as the integration surface.
- Expose actions for manage, show, hide, focus, restore, and reveal in Finder.

### Files

- `extensions/raycast`
- `README.md`

### Success Criteria

- Raycast can act as a thin UI layer over the CLI rather than a separate automation stack.

### Implemented

- Added a local Raycast extension scaffold in `extensions/raycast`.
- The extension now treats the installed GhostTile CLI as the canonical backend instead of reaching into workspace build products.
- Validated the extension package with `npm install` and `npm run typecheck`.

## Phase 3: Attention Notifications [Implemented, Needs Validation]

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

### Implemented

- The injected helper now watches the hidden app's Dock badge label and emits a distributed attention notification when a non-empty badge appears while hidden.
- The app now observes attention notifications per managed bundle ID, rate-limits duplicate alerts, and delivers a macOS user notification.
- Clicking the notification reveals the app in the Dock if needed and activates it through GhostTile.

## Phase 4: Modern Expose View [Implemented, Needs Validation]

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

### Implemented

- Added a persistent overview panel with cached-first rendering instead of synchronous capture on open.
- Moved live preview capture to an async, on-demand path that only runs after the user opens Overview and only for running managed apps.
- Switched live previews from whole-screen rect capture to per-window capture.
- Added entry points from both the main window and the status bar menu.
- Added graceful fallback to icon-based cards when window capture is unavailable.
- Added keyboard-driven selection and open/dismiss behavior for the Overview panel.
- Added a Screen Recording permission prompt path for window previews.
- Tuned the Overview window into a more compact four-card layout and aligned its light-mode styling with the main window.

## Phase 5: Global Shortcut Support [Completed]

### Objectives

- Add user-configurable global shortcuts for the primary GhostTile surfaces without reviving the old shortcut sprawl.

### Tasks

- Integrate a modern global shortcut library.
- Add shortcut recorders in Settings.
- Register global actions for opening the Overview panel and the main window.

### Files

- `Package.swift`
- `Sources/GhostTileApp/ShortcutController.swift`
- `Sources/GhostTileApp/SettingsView.swift`
- `Sources/GhostTileApp/GhostTileApp.swift`

### Success Criteria

- Users can assign and use global shortcuts to open the Overview panel and the main window from anywhere.

### Implemented

- Added `KeyboardShortcuts` as the global shortcut library.
- Added Settings recorders for both `Open Main Window` and `Open Overview`.
- Registered global shortcuts for the main window and Overview panel.

## Phase 6: Main Window and Onboarding Refresh [Completed]

### Objectives

- Make the main window feel like the modern control center for GhostTile instead of a narrow utility panel.
- Align onboarding with the new visual language and current permission model.

### Tasks

- Redesign the main window as a managed-first workspace with a larger default size.
- Replace row-heavy managed app UI with denser icon-first cards.
- Move running apps into a compact secondary rail.
- Polish light mode to reduce heavy panel chrome.
- Update onboarding to match the main window's visual language.
- Add current permission guidance for App Management, Terminal, and Screen Recording.

### Files

- `Sources/GhostTileApp/MainWindowView.swift`
- `Sources/GhostTileApp/AppRowViews.swift`
- `Sources/GhostTileApp/GhostTileApp.swift`
- `Sources/GhostTileApp/OnboardingView.swift`

### Success Criteria

- Managed apps are visible at a glance without the app feeling cramped.
- Onboarding reflects the real modern macOS setup path and fits within the window cleanly.

### Implemented

- Rebuilt the main window into a larger managed-first dashboard with a compact running-app sidebar.
- Switched managed cards to a smaller icon-first two-column layout so typical managed sets are visible without immediate scrolling.
- Removed the Overview button from the main window and tightened the search and action layout.
- Applied a lighter light-mode treatment to the main window and Overview.
- Added the legacy GhostTile icon as a subtle watermark easter egg in the main window.
- Rebuilt onboarding to match the new visual system, centered the onboarding window, and fixed the step flow.
- Added looping old-to-new icon animation on step 1 and compact permission cards with inline `Grant` actions on step 3.

## Phase 7: CLI Maintenance and Dev Ergonomics [Completed]

### Objectives

- Keep the installed CLI aligned with the app bundle and make iteration on managed app preparation faster.

### Tasks

- Add a Settings action to reinstall the bundled CLI to `/usr/local/bin/ghosttile`.
- Add developer recipes for re-preparing one managed app or all managed apps.
- Preserve the CLI as the single source of truth for signing and preparation behavior.

### Files

- `Sources/GhostTileApp/SettingsView.swift`
- `Sources/ghosttile/Commands.swift`
- `justfile`

### Success Criteria

- Users can refresh the installed CLI from the app without manual copy commands.
- Developers can re-run the real GhostTile preparation path against managed apps after dylib or signing changes.

### Implemented

- Added `Install CLI` and `Reinstall CLI` flows in Settings backed by the bundled CLI binary.
- Added `ghosttile manage --force-prepare`.
- Added `just resign <app>` and `just resign-all` to re-run preparation against one or all managed apps.

## Phase 8: Hidden-App Policy Enforcement [Implemented, Needs Validation]

### Objectives

- Close the gap between old GhostTile and the rewrite for apps that try to promote themselves back into the Dock.

### Tasks

- Port the old `TransformProcessType` interception into the injected helper.
- Keep the existing `setActivationPolicy:` interception in place.
- Drive both transform paths explicitly on GhostTile show and hide notifications.

### Files

- `Resources/ghosthide.m`
- `Sources/GhostTileCore/Dylib.swift`

### Success Criteria

- Hidden apps like Electron-style clients stay accessory-only even when they try to foreground themselves through the Carbon transform path.

### Implemented

- Ported `TransformProcessType` interception into the bundled injected helper and the inline fallback source.
- Show, hide, and toggle notifications now drive both activation-policy and process-type transitions.

## Later Work

- Live validation against apps that aggressively re-promote themselves to the Dock.
- Decide whether to remove the runtime `xcrun clang` fallback and rely solely on the bundled `ghosthide.dylib`.
- Further Raycast UX polish now that the CLI contract is stable.

## Execution Order

1. CLI path-based management
2. Richer status bar actions
3. Raycast extension
4. Attention notifications
5. Expose view
6. Global shortcuts
7. Main window and onboarding refresh
8. CLI maintenance and dev ergonomics
9. Hidden-app policy enforcement

## Validation

- Run `swift build` after each implementation phase.
- Run `just build` when packaging or resources change.
- When changing shared app/core behavior, verify at least one GUI flow and one CLI flow conceptually.
