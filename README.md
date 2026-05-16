# GhostTile

GhostTile hides selected apps from the Dock and Cmd+Tab on macOS.

It ships as both:
- A native macOS menu bar app
- A CLI for scripting and recovery flows

Requires macOS 15+.

## What GhostTile Changes

GhostTile prepares managed apps by:

- staging `ghosthide.dylib` inside the target app bundle
- patching the main executable to load that helper
- re-signing the modified app ad hoc

That gives GhostTile a persistent way to keep selected apps out of the Dock after normal launches. If an app misbehaves, use `ghosttile restore "<App Name>"` to remove GhostTile's changes from that app.

## Install

### App

- Download the latest `GhostTile.app` archive from GitHub Releases, then move it to `/Applications`
- Or build locally with `just build`

### CLI

- GhostTile.app bundles a matching CLI and can install it from Settings
- Or build locally with `just build-cli`

## Quick Start

1. Launch `GhostTile.app`
2. Add an app from the `Running` list, click `+`, or drag an `.app` bundle into the `Managed` column
3. GhostTile prepares the app if needed, relaunches it hidden, and stores it in the managed list
4. Use the managed row actions to show it in the Dock, hide it again, or restore it

The status bar menu also lets you toggle whether GhostTile itself appears in the Dock, activate managed apps, show or hide them, and open Settings.

## CLI Usage

```bash
ghosttile list
ghosttile manage "App Name"
ghosttile manage "/Applications/App Name.app"
ghosttile status
ghosttile hide "App Name"
ghosttile show "App Name"
ghosttile focus "App Name"
ghosttile restore "App Name"
```

Use `--json` with `list` and `status` for machine-readable output.

## Permissions

- App Management: needed to prepare and restore apps from the GUI
- Terminal administrator prompt: used for fallback flows when protected file operations fail
- Screen Recording: only needed for Overview thumbnails

## Caveats

- System apps and SIP-protected apps are not supported
- Some hardened apps need extra preparation before they can be launched with the helper dylib
- Some apps can still promote themselves back into the Dock after launch
- App preparation modifies the target bundle in place, so use `restore` before troubleshooting unrelated app issues

## Spotlight Actions

GhostTile registers App Shortcuts so you can hide, show, and focus managed apps straight from Spotlight (and Shortcuts.app). Open Spotlight and type "GhostTile" to see the available actions.

## Auto-update

GhostTile uses Sparkle for in-app updates in signed release builds. You can check manually from the app, or leave automatic checks enabled in Settings.

## Development Docs

- Contributor setup: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security reporting: [SECURITY.md](SECURITY.md)
- Internal engineering notes: [`docs/dev`](docs/dev)

## License

BSL 1.1 — source available and free to use, modify, and redistribute. The paid marketplace restriction remains in the license as a legacy reminder of the project's commercial roots. Converts to Apache-2.0 on 2030-03-23. See [LICENSE](LICENSE).
