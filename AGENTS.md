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
- `docs/dev/roadmap.md`: shipped work and near-term follow-up.

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
- Service implementations live in focused subfolders under `Sources/GhostTileApp/Services`.
- `Services/ManagedApps`: managed app list, snapshots, config watching.
- `Services/Permissions`: System Settings permission guidance and helper overlay.
- `Services/Attention`: attention/notification observation and delivery.
- `Services/DockVisibility`: auto-hide, reapply, notification sending.
- `Services/AppActions`: high-level hide/launch/remove workflows.
- `Services/CLI`: consolidated CLI binary path resolution.
- `Services/Shortcuts`, `Services/Sponsors`, `Services/Updates`, `Services/Config`: focused support services.

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

## Version Control
- Use `jj` for source control operations in this repo: status, diff, log, change descriptions, bookmark movement, and Git pushes.
- Use `git` only when a task specifically needs GitHub/Git compatibility that `jj` does not cover.
- Abandon only empty jj changes with no description, and never abandon user work or non-empty changes without explicit confirmation.

## Release Pipeline
1. Bump `version` and `build_number` in `justfile`, `CFBundleShortVersionString` / `CFBundleVersion` in `project.yml`, `CFBundleShortVersionString` / `CFBundleVersion` in `Resources/Info.plist`, and `version` / `build` in `Sources/GhostTileCore/BuildInfo.swift`.
2. Write release notes to `releases/<version>.html` as an HTML body fragment with no wrapper tags.
3. Run `just build` to verify the release still builds.
4. Run `just release-dry-run` if you want a local package check without signing or notarization.
5. Run `just release` to sign, notarize, zip, update `docs/appcast.xml`, and upload the draft GitHub release.
6. Update the Homebrew tap via `just update-cask` after the final release zip exists.

Sparkle release notes come from `releases/<version>.html`. Do not publish a release with an empty appcast description.

## Code Style
- Only add comments that explain *why*, not *what*. If the code is self-explanatory, skip the comment.
- Keep one top-level Swift `enum` or `struct` per file, with the filename matching the type name.

## Editing Guidance
- Put new app service code in a feature subfolder under `Sources/GhostTileApp/Services`; do not add new service files directly at the Services root.
- Prefer changes in `GhostTileCore` when logic is shared between the app and CLI.
- Use the existing service/view-model split. Don't route new behavior through `AppViewModel` — put logic in focused services or `AppOperations`.
- `ManagedAppItem` is the UI-facing app type. `ManagedAppRecord` is the core type. Don't mix them.
- CLI commands should use `AppManager` facade methods or core types directly, not app-layer services.
- Keep UI work aligned with the existing SwiftUI/AppKit mix. The app uses `NSWorkspace`, `NSStatusItem`, `NSOpenPanel`, and distributed notifications.
- Treat binary modification, codesigning, App Management permissions, and privileged file operations as high-risk paths. Small behavior changes here can break the main workflow.
- Do not remove the fallback paths for protected apps unless you have validated both GUI and CLI flows.
- When touching config behavior, verify both app-driven and CLI-driven updates. The GUI reflects `~/.config/ghosttile/config.json` changes via `ConfigWatcher` without a restart.

## Validation Expectations
- Always run `just format` and `just lint` before committing.
- Always run `swift build` after code changes.
- Add a focused unit test or UI test for regression fixes when automation can reasonably cover the behavior.
- If you change packaging or resources, also run `just build`.
- If you change app/core interaction, verify at least one CLI path and one GUI path conceptually, even if you cannot execute the full macOS workflow in automation.

## Review Focus
- Look for crashes from forced unwraps around `NSRunningApplication`, bundle URLs, and resource loading.
- Check for stale UI state caused by async timing, file watchers, or `Thread.sleep` coordination.
- Watch for regressions in protected-app flows: SIP detection, hardened runtime checks, backup/restore, and admin fallback behavior.
- Keep user-facing errors actionable. Prefer explicit recovery instructions over silent failure.
