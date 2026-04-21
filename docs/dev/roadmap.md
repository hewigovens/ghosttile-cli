# GhostTile Roadmap

This is a brief contributor-facing roadmap for the current rewrite.

## Done

- Rebuilt GhostTile as a Swift package with shared core, CLI, and app targets.
- Moved the CLI onto shared core logic and stable JSON output.
- Rebuilt app management around explicit preparation, restore, and launch paths.
- Restored the status bar workflow, Overview, onboarding refresh, and global shortcuts.
- Added attention notifications for hidden apps.
- Added CI, tests for the helper and Mach-O paths, and a cleaner release workflow.
- Added a local Raycast extension built on top of the CLI.

## Next

- Reduce remaining `AppViewModel` coordination and keep pushing logic into focused services.
- Keep improving protected-app behavior, especially around relaunch and activation-policy edge cases.
- Tighten restore and recovery paths for apps that need manual or elevated intervention.
- Improve diagnostics for cases where apps promote themselves back into the Dock.
- Continue simplifying the public docs and contributor workflow as the rewrite settles.
