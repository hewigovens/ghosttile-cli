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

## Common Commands
- `swift build`: build all targets in debug.
- `swift build -c release --product GhostTileApp`: build the app binary.
- `swift build -c release --product ghosttile`: build the CLI binary.
- `just build`: assemble `GhostTile.app`, compile `ghosthide.dylib`, and codesign the bundle.
- `just run`: rebuild and open the app bundle.
- `just build-cli`: build only the CLI in release.

## Editing Guidance
- Prefer changes in `GhostTileCore` when logic is shared between the app and CLI.
- Keep UI work aligned with the existing SwiftUI/AppKit mix. The app currently uses `NSWorkspace`, `NSStatusItem`, `NSOpenPanel`, and AppleScript bridges where needed.
- Treat binary modification, codesigning, App Management permissions, and privileged file operations as high-risk paths. Small behavior changes here can break the main workflow.
- Do not remove the fallback paths for protected apps unless you have validated both GUI and CLI flows.
- When touching config behavior, verify both app-driven and CLI-driven updates. The GUI is expected to reflect `~/.config/ghosttile/config.json` changes without a restart.

## Validation Expectations
- Always run `swift build` after code changes.
- If you change packaging or resources, also run `just build`.
- If you change app/core interaction, verify at least one CLI path and one GUI path conceptually, even if you cannot execute the full macOS workflow in automation.

## Review Focus
- Look for crashes from forced unwraps around `NSRunningApplication`, bundle URLs, and resource loading.
- Check for stale UI state caused by async timing, file watchers, or `Thread.sleep` coordination.
- Watch for regressions in protected-app flows: SIP detection, hardened runtime checks, backup/restore, and admin fallback behavior.
- Keep user-facing errors actionable. Prefer explicit recovery instructions over silent failure.
