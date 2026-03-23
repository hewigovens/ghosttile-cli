# GhostTile

GhostTile hides selected apps from the Dock and Cmd+Tab on macOS.

It ships as both:
- A native macOS app with a menu bar interface
- A CLI for managing hidden apps directly from Terminal

Requires macOS 15+.

## App Usage

1. Launch `GhostTile.app`
2. Add an app from the `Running` list, click `+`, or drag an `.app` bundle into the `Managed` column
3. GhostTile will prepare the app if needed, relaunch it hidden, and store it in the managed list
4. Use the managed row actions to show it in the Dock, hide it again, or remove it from management

The status bar menu also lets you toggle whether GhostTile itself appears in the Dock, activate managed apps, show/hide them, or open Settings.

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

## Raycast Extension

The Raycast extension lives in `extensions/raycast` and shells out to the `ghosttile` CLI.

## Permissions and Caveats

- System apps and SIP-protected apps are not supported
- Some hardened apps need extra preparation before they can be launched with the helper dylib
- Some restore / prepare flows may require administrator privileges
- Overview thumbnails may require Screen Recording permission
- GhostTile is best-effort: some apps may override activation policy after launch

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

BSL 1.1 — free to use, modify, and redistribute; paid app store distribution requires permission. Converts to Apache-2.0 on 2030-03-23. See [LICENSE](LICENSE).
