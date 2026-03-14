# GhostTile Raycast Extension

This extension shells out to the local `ghosttile` CLI. It does not reimplement GhostTile logic in JavaScript.

## Requirements

- Raycast
- `ghosttile` installed and reachable from Raycast

If `ghosttile` is not on Raycast's `PATH`, set the `GhostTile Binary Path` preference to the absolute binary path, for example:

```text
/usr/local/bin/ghosttile
```

## Local Development

```bash
cd extensions/raycast
npm install
npm run typecheck
```

Then open the extension in Raycast developer tools or run the usual Raycast extension workflow.
