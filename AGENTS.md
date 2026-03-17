# AGENTS.md

## Project Overview
- `GhostTile` is a Swift Package with three targets:
- `GhostTileCore`: shared process, config, signing, logging, and helper logic.
- `ghosttile`: CLI built with `swift-argument-parser`.
- `GhostTileApp`: macOS SwiftUI app and menu bar UI.

## Repository Layout
- `Sources/GhostTileCore`: core logic used by both the app and CLI.
- `Sources/ghosttile`: CLI entrypoint and subcommands.
- `Sources/GhostTileApp`: SwiftUI views, app lifecycle, and status bar integration.
- `Resources`: app bundle resources, `Info.plist`, icons, and `ghosthide.m`.
- `justfile`: local build, packaging, install, and release helpers.
- `docs/refactor.md`: architecture decisions and refactor completion status.

## Architecture

### GhostTileCore — domain types
- `AppManager`: thin façade delegating to focused types below.
- `AppResolver`: resolves apps from bundle ID, path, name, or running app.
- `AppPreparationManager`: binary backup, Mach-O patching, entitlements, codesign.
- `AppRestoreManager`: binary restoration and cleanup.
- `AppLauncher`: launch/quit/focus, SIP and Apple-first-party checks.
- `ShellRunner`: command execution with stderr capture.
- `ManagedAppRecord` / `ManagedAppStateReader`: shared core model and snapshot factory.
- `Config`: reads/writes `~/.config/ghosttile/config.json`.

### GhostTileApp — services
- `ManagedAppsStore`: owns managed app list, publishes snapshots, drives config watching.
- `ConfigWatcher`: file system monitoring with dispatch sources.
- `DockVisibilityController`: auto-hide, reapply, notification sending.
- `AppOperations`: high-level hide/launch/remove workflows.
- `CLIPaths`: consolidated CLI binary path resolution.

### GhostTileApp — view models
- `AppViewModel`: app-wide coordinator for loading state, errors, workspace observers.
- `MainWindowViewModel`: query filtering, managed/running app lists, counts.
- `OverviewViewModel`: selection, arrow navigation, search.
- `SettingsViewModel`: CLI install status, version checking, launch-at-login.

### GhostTileApp — shared UI types
- `ManagedAppItem`: standalone UI wrapper over `ManagedAppRecord` (icon + category).
- `IconTileView`, `SearchFieldView`, `SectionHeaderView`, `StatusPill`: reusable primitives.
- `SettingsSectionCard`, `SettingsRowIcon`: settings-specific chrome.

### CLI — commands
- `CLIShared`: helper functions for JSON output and managed app resolution.
- `ManagePrepareCommands`, `QueryCommands`, `FocusCommand`, `RestoreCommand`, `VisibilityCommands`: individual command files.

## Common Commands
- `swift build`: build all targets in debug.
- `swift build -c release --product GhostTileApp`: build the app binary.
- `swift build -c release --product ghosttile`: build the CLI binary.
- `just build`: assemble `GhostTile.app`, compile `ghosthide.dylib`, and codesign the bundle.
- `just run`: rebuild and open the app bundle.
- `just build-cli`: build only the CLI in release.

## Editing Guidance
- Prefer changes in `GhostTileCore` when logic is shared between the app and CLI.
- Use the existing service/view-model split. Don't route new behavior through `AppViewModel` — put logic in focused services or `AppOperations`.
- `ManagedAppItem` is the UI-facing app type. `ManagedAppRecord` is the core type. Don't mix them.
- CLI commands should use `AppManager` facade methods or core types directly, not app-layer services.
- Keep UI work aligned with the existing SwiftUI/AppKit mix. The app uses `NSWorkspace`, `NSStatusItem`, `NSOpenPanel`, and distributed notifications.
- Treat binary modification, codesigning, App Management permissions, and privileged file operations as high-risk paths. Small behavior changes here can break the main workflow.
- Do not remove the fallback paths for protected apps unless you have validated both GUI and CLI flows.
- When touching config behavior, verify both app-driven and CLI-driven updates. The GUI reflects `~/.config/ghosttile/config.json` changes via `ConfigWatcher` without a restart.

## Validation Expectations
- Always run `swift build` after code changes.
- If you change packaging or resources, also run `just build`.
- If you change app/core interaction, verify at least one CLI path and one GUI path conceptually, even if you cannot execute the full macOS workflow in automation.

## Review Focus
- Look for crashes from forced unwraps around `NSRunningApplication`, bundle URLs, and resource loading.
- Check for stale UI state caused by async timing, file watchers, or `Thread.sleep` coordination.
- Watch for regressions in protected-app flows: SIP detection, hardened runtime checks, backup/restore, and admin fallback behavior.
- Keep user-facing errors actionable. Prefer explicit recovery instructions over silent failure.
