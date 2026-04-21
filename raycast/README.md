# GhostTile Raycast Extension

Manage GhostTile apps from Raycast.

## Requirements

- Raycast on macOS
- A working `ghosttile` CLI installation

The extension shells out to the GhostTile CLI. It does not bundle its own copy of `ghosttile`.

If the CLI is not on your shell `PATH`, set `GhostTile Binary Path` in the extension preferences to the absolute path of the installed binary.

## Local Development

```bash
cd raycast
pnpm install
pnpm run lint
pnpm run typecheck
```

## Source Layout

- `src/managed-apps.tsx`: Raycast list view
- `src/use-managed-apps.ts`: loading and refresh logic
- `src/ghosttile-runner.ts`: CLI invocation wrapper
