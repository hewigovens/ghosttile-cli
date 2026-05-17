# GhostTile

<p align="center">
  <img src="docs/imgs/appIcon-new.png" alt="GhostTile" width="128">
</p>

Hide running macOS apps from the Dock and Cmd+Tab. Native menu-bar app, native CLI, signed and notarized — no daemons, no runtime swizzling.

> Why this exists and how it's built: see [Background](#background).

Requires macOS 15+.

## Features

- Hide any running app from the Dock and Cmd+Tab while it keeps working in the background
- Status bar menu plus Dock submenu for one-click reveal / hide / activate
- Quick Switch overlay (`⌃⇧Tab`) for keyboard-only navigation between hidden apps
- **Spotlight & Shortcuts.app integration** via native App Intents — hide, show, focus from `⌘Space`
- CLI with stable JSON output for scripts, cron, Hammerspoon, Alfred
- `ghosttile://` URL scheme for Shortcuts.app and external launchers
- Sparkle auto-updates in signed builds

## Install

### Homebrew

```bash
brew install --cask hewigovens/tap/ghosttile
```

### Direct download

Grab the latest signed + notarized build from [GitHub Releases](https://github.com/hewigovens/ghosttile-cli/releases/latest) and move `GhostTile.app` to `/Applications`.

### From source

```bash
git clone https://github.com/hewigovens/ghosttile-cli
cd ghosttile-cli
just build
```

The app bundle ships with a matching `ghosttile` CLI; install it from **Settings → CLI**, or build it standalone with `just build-cli`.

## Quick Start

1. Launch `GhostTile.app`.
2. Add an app from the **Running** sidebar, click **+**, or drag an `.app` bundle into the **Managed** column.
3. GhostTile prepares the bundle (binary patch + re-sign), relaunches the app hidden, and records it in the managed list.
4. Use the row actions to show in the Dock, hide again, focus, or restore the original binary.

The status bar menu also toggles GhostTile's own Dock presence, activates managed apps, shows/hides them, and opens Settings.

## How It Works

GhostTile prepares each managed app by:

1. Staging `ghosthide.dylib` inside the target app bundle.
2. Patching the main executable to load that helper at launch.
3. Re-signing the modified bundle ad hoc.

The app then launches normally but presents itself as an accessory process — no Dock tile, no Cmd+Tab entry. The dylib also listens for distributed notifications so GhostTile can flip Dock visibility live without restarting the app.

If anything goes wrong, `ghosttile restore "<App Name>"` restores the original binary and removes GhostTile's modifications.

## Spotlight Actions

GhostTile registers four App Shortcuts that surface in Spotlight and in Shortcuts.app:

| Action | Phrase |
|---|---|
| Hide app from Dock | *"Hide \<app\> with GhostTile"* |
| Show app in Dock | *"Show \<app\> with GhostTile"* |
| Focus managed app | *"Focus \<app\> with GhostTile"* |
| Open the GhostTile window | *"Open GhostTile"* |

Trigger any of them from `⌘Space`. The same actions are available in Shortcuts.app for use in automations.

## CLI

```bash
ghosttile list                       # managed apps
ghosttile status                     # running + dock state
ghosttile manage "App Name"
ghosttile manage "/Applications/App Name.app"
ghosttile hide "App Name"
ghosttile show "App Name"
ghosttile focus "App Name"
ghosttile restore "App Name"
```

Pass `--json` to `list` and `status` for machine-readable output.

## Permissions

- **App Management** — required to prepare and restore apps from the GUI.
- **Terminal administrator** — used as a fallback for protected file operations.
- **Screen Recording** — only needed for the Overview thumbnail grid.

## Caveats

- System apps and SIP-protected apps are not supported.
- Some hardened apps need extra preparation before they can launch with the helper dylib.
- A few apps re-promote themselves into the Dock after launch; that's app-specific behavior, not a GhostTile bug.
- App preparation modifies the target bundle in place — `restore` it before troubleshooting unrelated app issues.

## Auto-update

Signed releases ship with Sparkle. Check manually from **Check for Updates…** in the GhostTile menu, or leave automatic checks enabled in Settings.

## Background

GhostTile 2.0 is a ground-up rewrite. The original stalled against modern macOS hardening; the new version is built around explicit staging, code signing, and notarization rather than runtime tricks. [Rewriting GhostTile for Modern macOS](https://hewig.dev/posts/rewriting-ghosttile) covers the motivation and design decisions in more detail.

## Development

- Contributor setup: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security reporting: [SECURITY.md](SECURITY.md)
- Engineering notes: [`docs/dev`](docs/dev)

## License

BSL 1.1 — source available and free to use, modify, and redistribute. The paid-marketplace restriction is a legacy reminder of the project's commercial roots; the license converts to Apache-2.0 on 2030-03-23. See [LICENSE](LICENSE).
