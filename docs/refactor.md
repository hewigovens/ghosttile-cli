# GhostTile Refactor Plan

## Why This Exists

GhostTile has already gone through a large file-splitting pass. That improved readability, but it did not fully solve the underlying maintenance problem.

The current codebase still has these structural issues:

- `AppViewModel` is still the app brain, just spread across extensions.
- several SwiftUI screens still mix:
  - UI layout
  - styling
  - orchestration
  - product behavior
- `AppManager` still bundles multiple domains behind one façade:
  - resolving apps
  - preparing and signing apps
  - restoring apps
  - launching apps
  - shell execution
- the app and CLI still project app state through separate models in places where they should share a core representation
- some extensions are still acting as "overflow files" instead of reflecting truly separate responsibilities

This document describes the target architecture and a safe order for getting there.

## Refactor Principles

### 1. Split app state from app actions

The app should stop routing nearly all behavior through `AppViewModel`.

Target direction:

- keep one thin screen-facing coordinator if needed
- move real logic into focused services
- treat view models as adapters over services, not as the source of truth

### 2. Prefer real types over extension-only decomposition

Extensions are useful when:

- they organize protocol conformances
- they group a small set of related helpers
- they add behavior that clearly belongs to the base type

Extensions are not enough when:

- the type is still a god object
- the extension names become `+Actions`, `+Behavior`, `+Layout`, `+Styling`, `+Misc`
- the real complexity is still centralized

In those cases, create a new type instead.

### 3. Share core models, not duplicated projections

The CLI and app should not each invent their own slightly different app-state model unless the UI truly needs it.

Default rule:

- define shared state in `GhostTileCore`
- let app and CLI add thin adapters on top

### 4. Build a small design system

Repeated UI patterns should become reusable primitives instead of being hand-built in every screen.

That includes:

- section cards
- pills and badges
- panel surfaces
- icon tiles
- search fields
- section headers
- empty states

### 5. Refactor behavior first, not naming first

Renaming large types without changing ownership does not make the codebase simpler.

Good refactors should:

- reduce duplication
- narrow responsibilities
- improve testability
- reduce the number of places that must change for one feature

## Target Shape

## GhostTileApp

### Replace one large app view model with smaller services

The current `AppViewModel` should eventually be replaced by a thinner composition of services and screen-specific view models.

Recommended service layer:

- `ManagedAppsStore`
  - owns the current managed app list
  - projects managed state from config + running apps
  - publishes snapshots for UI consumers
- `ConfigWatcher`
  - watches `~/.config/ghosttile/config.json`
  - emits change events
  - owns file-watching behavior and debounce
- `DockVisibilityController`
  - owns show/hide/toggle notification sending
  - knows how to query current hidden state
  - centralizes Dock-policy logic instead of scattering it through the app
- `ManagedAppLauncher`
  - launches managed apps
  - focuses/reveals apps
  - keeps the "launch visible" vs "launch hidden" behavior in one place
- `AttentionMonitor`
  - observes helper-side attention notifications
  - owns rate limiting and notification fan-out
- `SponsorNudgeController`
  - can stay as a separate concern
  - should remain independent from the app-state pipeline

### Introduce screen-specific view models

Current issue:

- one app-wide model feeds the menu bar, settings, main window, overview, onboarding, and notifications

Target:

- `MainWindowViewModel`
  - owns filtering and presentation state for the main window
  - depends on `ManagedAppsStore` and `AppOperations`
- `OverviewViewModel`
  - owns Overview filtering, selection, and preview-related state
  - depends on `ManagedAppsStore` and Overview-specific services
- `SettingsViewModel`
  - owns CLI installation state, build info projection, and preferences surface
  - does not need the full app state

The screens should consume only what they need.

### Recommended app-side support types

These are likely useful shared types:

- `ManagedAppsSnapshot`
  - immutable state describing the current managed/running/hidden picture
- `AppOperations`
  - high-level commands used by the app UI
  - may be backed by `DockVisibilityController`, `ManagedAppLauncher`, and config services
- `AttentionState`
  - app-facing attention status model
  - useful if notifications or badges grow later

## GhostTileCore

### Split `AppManager` into real domain types

Current issue:

- `AppManager` is still effectively a multi-domain façade with extension files

Target direction:

- `AppResolver`
  - resolves app input from path, bundle ID, app name, and running-app matches
- `AppPreparationManager`
  - handles binary preparation
  - helper staging
  - Mach-O patching
  - entitlements preservation
  - codesign flow
- `AppRestoreManager`
  - handles backup restore and cleanup
- `AppLauncher`
  - handles launch/focus/reveal behaviors
  - owns launch environment decisions
- `ShellRunner`
  - owns command execution and shell capture
  - replaces duplicated process-launch glue

`AppManager` can remain temporarily as a compatibility façade over these types, so call sites do not all need to change at once.

### Converge shared models

Likely candidates to unify:

- `CLIAppRecord`
- `AppViewModel.AppItem`
- any duplicate config-derived app structures in the app layer

Preferred end state:

- one core `ManagedAppRecord` or equivalent
- app-specific formatting stays in app-side adapters
- CLI-specific formatting stays in CLI-side encoders

### Keep `MachOEditor.swift` focused

`MachOEditor.swift` is complex, but it is a legitimate complexity hotspot.

Do not split it unless:

- there is clear duplication inside it
- command-level parsing and patch writing can be separated cleanly

The current priority is higher-level ownership, not slicing low-level binary editing for its own sake.

## UI Layer

### Build a reusable design system

Current repeated patterns already visible across the app:

- panel backgrounds
- rounded surface cards
- section headers
- search fields
- icon tiles
- status pills
- empty state cards

Recommended structure:

- `Sources/GhostTileApp/UI/SurfaceCard.swift`
- `Sources/GhostTileApp/UI/StatusPill.swift`
- `Sources/GhostTileApp/UI/SearchField.swift`
- `Sources/GhostTileApp/UI/SectionHeader.swift`
- `Sources/GhostTileApp/UI/IconTile.swift`
- `Sources/GhostTileApp/UI/EmptyStateCard.swift`

This does not need to be over-engineered. The goal is consistency and reuse, not a full design-system framework.

### Current extraction status

These primitives already exist and should be treated as the start of that layer:

- `SearchFieldView`
- `SectionHeaderView`
- `StatusPill`
- `SettingsSectionCard`
- `SettingsRowIcon`

Next step is to continue pulling shared surfaces out of:

- `MainWindowView+Layout.swift`
- `OverviewView+Layout.swift`
- `SettingsView+Components.swift`

without changing behavior.

## Phase Completion Status

### Phase A: UI primitive extraction — DONE

Extracted primitives:

- `IconTileView` — reusable icon tile with configurable size, corner radius, fill, stroke
- `SearchFieldView` — search input with dark mode support and optional focus binding
- `SectionHeaderView` — title/subtitle header with configurable sizes
- `StatusPill` — colored capsule badge
- `SettingsSectionCard` — card wrapper for settings sections
- `SettingsRowIcon` — icon wrapper for settings rows

All primitives are used by MainWindowView, OverviewView, SettingsView, ManagedAppCard, RunningAppSidebarRow, and OverviewCard.

### Phase B: Core execution helpers — DONE

Extracted types:

- `ShellRunner` — command execution with stderr capture
- `AppResolver` — bundle path, running app, and NSBundle resolution
- `AppPreparationManager` — backup, entitlements, Mach-O patching, codesign
- `AppRestoreManager` — binary restoration and cleanup
- `AppLauncher` — launch/quit/focus, SIP and Apple-first-party checks

`AppManager` remains as a thin façade delegating to these types.

### Phase C: App state pipeline — DONE

Extracted services:

- `ManagedAppsStore` — owns managed app list, publishes snapshots, config watching
- `ConfigWatcher` — file system monitoring with dispatch sources
- `DockVisibilityController` — auto-hide, reapply, notification sending
- `ManagedAppsSnapshotBuilder` — builds snapshots from core records with icons and categories
- `AppOperations` — high-level hide/launch/remove workflows

### Phase D: Screen-specific view models — DONE

Screen view models:

- `MainWindowViewModel` — query filtering, managed/running app lists, counts
- `OverviewViewModel` — selection, arrow navigation, search
- `SettingsViewModel` — CLI install status, version checking, launch-at-login

### Phase E: Model convergence — DONE

- `ManagedAppRecord` is the shared core model in `GhostTileCore`
- `ManagedAppItem` is the standalone UI wrapper (icon + category) — no longer nested in `AppViewModel`
- CLI uses `ManagedAppRecord` directly for JSON output
- `ManagedAppsStore` publishes `[ManagedAppItem]` independently of `AppViewModel`

### CLI split — DONE

- `CLIShared` — helper functions for JSON output and managed app resolution
- `FocusCommand` — focus/activate command
- `ManagePrepareCommands` — manage/prepare with error handling
- `QueryCommands` — list/status with JSON output
- `RestoreCommand` — restore with file restoration
- `VisibilityCommands` — hide/show notification commands

### Extension cleanup — DONE

Folded trivial extensions:

- `AppViewModel+ConfigMonitoring` (7 lines) → folded into `AppViewModel.swift`
- `OverviewView+Behavior` (3 lines) → folded into `OverviewView.swift`
- `OverviewView+Styling` (single property) → folded into `OverviewView+Layout.swift`

Remaining extensions have clear, focused responsibilities.

## Current Architecture

### AppViewModel

Still serves as the app-wide coordinator (~130 lines base + 3 extensions):

- `+Actions` — hide/show/remove/launch orchestration
- `+HiddenState` — dock visibility helpers, refresh scheduling
- `+Attention` — distributed notification observers for managed apps

This is acceptable per the refactor principles: "keep one thin screen-facing coordinator if needed." The real logic lives in the services.

### Remaining opportunities

These are not blockers but could be addressed later:

- `AppViewModel` still holds workspace observers (launch/terminate). These could move to a dedicated `WorkspaceObserver` service if the coordinator grows further
- The status bar menu still queries `vm.hiddenApps` directly — could route through a menu-specific view model if the menu grows
- Some view extension files (`MainWindowView+Styling`, `MainWindowView+Actions`) are small but have clear responsibilities so they were kept as-is
