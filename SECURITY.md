# Security Policy

GhostTile works in a sensitive area: it modifies app bundles, re-signs binaries, launches helper code inside managed apps, and sometimes falls back to elevated file operations.

Please avoid public disclosure first for issues involving:

- privilege escalation
- arbitrary code execution
- bundle-signing or helper-injection bypasses
- unsafe restore or patch behavior that can corrupt third-party apps

## Reporting

- Prefer GitHub's private vulnerability reporting for this repository if it is enabled
- Otherwise contact the maintainer directly through GitHub before publishing details

## Scope

The most security-sensitive areas are:

- `Resources/ghosthide.m`
- `Sources/GhostTileCore/AppPreparationManager.swift`
- `Sources/GhostTileCore/AppRestoreManager.swift`
- `Sources/GhostTileCore/FileOperations.swift`
- `Sources/GhostTileCore/HelperClient.swift`

When reporting an issue, include:

- GhostTile version and build
- macOS version
- target app name and bundle ID
- whether `sudo` or App Management permissions were involved
- a minimal reproduction
