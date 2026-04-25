# Contributing to GhostTile

## Requirements

- macOS 15 or newer
- Xcode or Command Line Tools with SwiftPM support
- `just` for shortcut commands

## Development loop

```bash
swift build                        # debug build
swift test                         # test suite
just build                         # assemble GhostTile.app + ghosthide.dylib + codesign
just run                           # rebuild and open
just build-cli                     # build only the CLI
just format && just lint           # local cleanup
just format-check                  # CI-equivalent formatting check
```

If you change packaging, resources, or release metadata, also run `just build`.

## Architecture

```
Sources/GhostTileCore   — shared core logic (AppManager, Config, signing, logging)
Sources/GhostTileApp    — macOS app (SwiftUI + AppKit, menu bar, settings)
Sources/ghosttile       — CLI entrypoint and commands
Resources               — app bundle resources, icons, Info.plist, helper source
```

See [AGENTS.md](AGENTS.md) for detailed architecture and editing guidance.

## Internal Docs

Internal engineering notes live under [`docs/dev`](docs/dev). They are useful for implementation context, but they are not end-user documentation and may describe incomplete or experimental work.

## Release Notes

Release signing intentionally requires explicit environment variables:

- `DEVELOPER_ID_APPLICATION`
- `NOTARY_PROFILE`
- `SPARKLE_SIGN_UPDATE`

That avoids leaking maintainer-specific signing identities into contributor workflows.

Release notes live in `releases/<version>.html` and are embedded into Sparkle appcast entries. Keep them as an HTML body fragment with no wrapper tags.

## Security

Please follow [SECURITY.md](SECURITY.md) for sensitive reports involving binary patching, signing, or privilege boundaries.

## Repository layout

- `Sources/GhostTileCore`: shared core logic
- `Sources/GhostTileApp`: macOS app and SwiftUI UI
- `Sources/ghosttile`: CLI entrypoint and commands
- `Resources`: app bundle resources, icons, Info.plist, injected helper source
- `justfile`: local build, packaging, and install commands
