# Contributing to GhostTile

## Requirements

- macOS 15 or newer
- Xcode or Command Line Tools with SwiftPM support
- `just` for shortcut commands

## Development loop

```bash
swift build             # debug build
just build              # assemble GhostTile.app + ghosthide.dylib + codesign
just run                # rebuild and open
just build-cli          # build only the CLI
just dist               # create distributable zip
just format && just lint  # before committing
```

## Architecture

```
Sources/GhostTileCore   — shared core logic (AppManager, Config, signing, logging)
Sources/GhostTileApp    — macOS app (SwiftUI + AppKit, menu bar, settings)
Sources/ghosttile       — CLI entrypoint and commands
Resources               — app bundle resources, icons, Info.plist, helper source
```

See [CLAUDE.md](CLAUDE.md) for detailed architecture and editing guidance.

## Repository layout

- `Sources/GhostTileCore`: shared core logic
- `Sources/GhostTileApp`: macOS app and SwiftUI UI
- `Sources/ghosttile`: CLI entrypoint and commands
- `Resources`: app bundle resources, icons, Info.plist, injected helper source
- `justfile`: local build, packaging, and install commands
