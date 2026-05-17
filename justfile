default:
    @just --list

app := "GhostTile.app"
dev_app := "GhostTile Dev.app"
bundle_id := "dev.hewig.ghosttile"
dev_bundle_id := bundle_id + ".dev"
deployment_target := "15.0"

# Build the release GhostTile.app (ad-hoc signed). Canonical artifact for `dist`, `release`, and `install`.
build: build-cli
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p Sources/GhostTileApp/app.icon/Assets
    cp docs/imgs/icon.svg Sources/GhostTileApp/app.icon/Assets/ghost.svg
    echo "Building {{app}} via Xcode..."
    xcodegen generate --spec project.yml --project .
    xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Release build 2>&1 | xcbeautify
    app_path="$(xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/GhostTile.app"
    rm -rf "{{app}}"
    cp -R "$app_path" "{{app}}"
    codesign --force --sign - "{{app}}"
    echo "Built {{app}} ($(du -sh "{{app}}" | cut -f1))"

# Build a side-by-side dev variant `GhostTile Dev.app` with bundle id `dev.hewig.ghosttile.dev`.
build-dev: build
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf "{{dev_app}}"
    cp -R "{{app}}" "{{dev_app}}"
    plist="{{dev_app}}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier {{dev_bundle_id}}" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName GhostTile Dev" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName GhostTile Dev" "$plist"
    codesign --force --sign - --deep "{{dev_app}}"
    echo "Built {{dev_app}} (bundle id: {{dev_bundle_id}})"

# Build the `ghosttile` CLI binary and `ghosthide.dylib` helper. Set GHOSTHIDE_DEBUG=1 to enable dylib debug logging.
build-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    MACOSX_DEPLOYMENT_TARGET={{deployment_target}} swift build -c release --product ghosttile
    echo "Compiling ghosthide.dylib for CLI..."
    ghosthide_debug_flag=""
    if [[ "${GHOSTHIDE_DEBUG:-0}" == "1" ]]; then
        ghosthide_debug_flag="-DGHOSTHIDE_DEBUG=1"
    fi
    xcrun clang -dynamiclib -arch arm64 -framework Cocoa \
        -mmacosx-version-min={{deployment_target}} \
        ${ghosthide_debug_flag:+$ghosthide_debug_flag} \
        -o .build/ghosthide.dylib Resources/ghosthide.m Resources/ghosthide_debug.m Resources/fishhook.c
    cp .build/ghosthide.dylib .build/release/ghosthide.dylib

# Re-prepare a single managed app (forces backup + Mach-O patch + resign).
resign app:
    #!/usr/bin/env bash
    set -euo pipefail
    just build-cli
    sudo .build/release/ghosttile prepare --force "{{app}}"

# Re-prepare every managed app. Iterates `ghosttile status --json` and runs `prepare --force` for each.
resign-all:
    #!/usr/bin/env bash
    set -euo pipefail
    just build-cli
    apps_json="$(
        .build/release/ghosttile status --json
    )"
    app_paths="$(
        printf '%s' "$apps_json" | /usr/bin/python3 -c 'import json, sys; apps = json.load(sys.stdin); print("\n".join(app["appPath"] for app in apps if app.get("appPath")))'
    )"
    if [[ -z "$app_paths" ]]; then
        echo "No managed apps."
        exit 0
    fi
    while IFS= read -r app_path; do
        [[ -n "$app_path" ]] || continue
        echo "Re-preparing $app_path..."
        sudo .build/release/ghosttile prepare --force "$app_path"
    done <<< "$app_paths"

# Build a Debug GhostTile.app and open it from DerivedData.
run: kill build-cli
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p Sources/GhostTileApp/app.icon/Assets
    cp docs/imgs/icon.svg Sources/GhostTileApp/app.icon/Assets/ghost.svg
    xcodegen generate --spec project.yml --project .
    xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Debug build 2>&1 | xcbeautify
    app_path="$(xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/GhostTile.app"
    open "$app_path"

# Build the dev variant and open it.
run-dev: build-dev
    open "{{dev_app}}"

# Kill any running GhostTile process.
kill:
    -pkill -f "{{app}}/Contents/MacOS/GhostTile"

# Kill then `run` — quick rebuild + relaunch cycle.
restart: kill run

# Run macOS UI tests. Pass a test id to narrow the run.
test-ui test_id='': build-cli
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p Sources/GhostTileApp/app.icon/Assets
    cp docs/imgs/icon.svg Sources/GhostTileApp/app.icon/Assets/ghost.svg
    xcodegen generate --spec project.yml --project .
    args=(
        -project GhostTile.xcodeproj
        -scheme GhostTileUITests
        -configuration Debug
        -sdk macosx
        -derivedDataPath .build/DerivedData
        -parallel-testing-enabled NO
    )
    if [[ -n "{{test_id}}" ]]; then
        args+=(-only-testing:"{{test_id}}")
    fi
    xcodebuild "${args[@]}" test | xcbeautify

# Install the release build to /Applications/GhostTile.app. Replaces any existing install.
install: build
    cp -r "{{app}}" /Applications/
    @echo "Installed to /Applications/{{app}}"

# Install the dev variant to /Applications/GhostTile Dev.app. Side-by-side with the prod install.
install-dev: build-dev
    rm -rf "/Applications/{{dev_app}}"
    cp -R "{{dev_app}}" "/Applications/{{dev_app}}"
    @echo "Installed to /Applications/{{dev_app}}"

# App release metadata. Sole source is the VERSION file at repo root; CLI versioning lives in
# BuildInfo.cliVersion/cliBuild and is bumped manually (independent of the app version).
version := `grep '^VERSION=' VERSION | cut -d= -f2`
build_number := `grep '^BUILD=' VERSION | cut -d= -f2`
signing_identity := "Developer ID Application: Tao Xu (V28VJH6B6S)"

# Bump the app version + build, mirror to project.yml/Info.plist/BuildInfo.swift. No args = auto patch + build. Usage: just set-version | just set-version 2.1.0 23
set-version new_version='' new_build='':
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck disable=SC1091
    source ./VERSION
    if [[ -z "{{new_version}}" && -z "{{new_build}}" ]]; then
        IFS='.' read -r maj min pat <<< "$VERSION"
        next_version="$maj.$min.$((pat + 1))"
        next_build=$((BUILD + 1))
    elif [[ -n "{{new_version}}" && -n "{{new_build}}" ]]; then
        next_version="{{new_version}}"
        next_build="{{new_build}}"
    else
        echo "Error: pass both version and build, or neither (auto-bump patch + build)." >&2
        exit 1
    fi
    if [[ ! "$next_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: version must be X.Y.Z, got '$next_version'" >&2
        exit 1
    fi
    if [[ ! "$next_build" =~ ^[0-9]+$ ]]; then
        echo "Error: build must be a positive integer, got '$next_build'" >&2
        exit 1
    fi
    printf 'VERSION=%s\nBUILD=%s\n' "$next_version" "$next_build" > VERSION
    sed -i '' -E "s/CFBundleShortVersionString: .*/CFBundleShortVersionString: $next_version/" project.yml
    sed -i '' -E "s/CFBundleVersion: \".*\"/CFBundleVersion: \"$next_build\"/" project.yml
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next_version" Resources/Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next_build" Resources/Info.plist
    sed -i '' -E "s/let version = \"[^\"]*\"/let version = \"$next_version\"/" Sources/GhostTileCore/BuildInfo.swift
    sed -i '' -E "s/let build = \"[^\"]*\"/let build = \"$next_build\"/" Sources/GhostTileCore/BuildInfo.swift
    echo "Bumped to $next_version ($next_build). Remember to write releases/$next_version.html."

# Produce dist/GhostTile-<version>.zip (ad-hoc signed). Used by `release-dry-run`; full `release` reuses the zip after notarization.
dist: build
    #!/usr/bin/env bash
    set -euo pipefail
    zip_path="dist/GhostTile-{{version}}.zip"
    bash scripts/package-release-zip.sh "{{app}}" "$zip_path"
    bash scripts/verify-release-archive.sh "$zip_path" signed

# Re-sign the build with the Developer ID identity (env DEVELOPER_ID_APPLICATION overrides). Prerequisite for notarization.
sign-release: build
    #!/usr/bin/env bash
    set -euo pipefail
    signing_identity="${DEVELOPER_ID_APPLICATION:-{{signing_identity}}}"
    echo "Signing {{app}} with ${signing_identity}..."
    # Sign all binaries and nested bundles (Sparkle framework, XPCs)
    find "{{app}}" -type f \( -name "*.dylib" -o -perm +111 \) -not -name "*.swift*" | while read binary; do
        codesign --force --timestamp --options runtime --sign "${signing_identity}" "$binary" 2>/dev/null || true
    done
    find "{{app}}" -name "*.xpc" -o -name "*.app" -o -name "*.framework" | sort -r | while read bundle; do
        codesign --force --timestamp --options runtime --sign "${signing_identity}" "$bundle"
    done
    codesign --force --timestamp --options runtime --sign "${signing_identity}" "{{app}}"
    codesign --verify --deep --strict --verbose=2 "{{app}}"
    echo "Signed {{app}}"

# Submit the signed build for notarization, staple the ticket, and rebuild the dist zip. Env NOTARY_PROFILE overrides keychain profile.
notarize-release: sign-release
    #!/usr/bin/env bash
    set -euo pipefail
    notary_profile="${NOTARY_PROFILE:-notarytool}"
    zip_path="dist/GhostTile-{{version}}.zip"
    bash scripts/package-release-zip.sh "{{app}}" "$zip_path"
    echo "Submitting $zip_path for notarization with profile ${notary_profile}..."
    xcrun notarytool submit "$zip_path" --keychain-profile "${notary_profile}" --wait
    xcrun stapler staple "{{app}}"
    xcrun stapler validate "{{app}}"
    bash scripts/package-release-zip.sh "{{app}}" "$zip_path"
    bash scripts/verify-release-archive.sh "$zip_path" notarized

# Full release: sign + notarize + Sparkle-sign + update appcast + create draft GitHub release. Review & publish on GitHub when done.
release: notarize-release
    #!/usr/bin/env bash
    set -euo pipefail
    zip_path="dist/GhostTile-{{version}}.zip"
    notes_path="releases/{{version}}.html"
    sparkle_bin="${SPARKLE_SIGN_UPDATE:-}"
    if [ -z "$sparkle_bin" ]; then
        sparkle_bin=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/GhostTile-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" -type f 2>/dev/null | head -1)
    fi
    if [ -z "$sparkle_bin" ] || [ ! -x "$sparkle_bin" ]; then
        echo "Could not locate Sparkle sign_update. Set SPARKLE_SIGN_UPDATE or run 'just build' first." >&2
        exit 1
    fi
    sign_output=$("$sparkle_bin" "$zip_path" 2>&1) || {
        echo "Error: Sparkle sign_update failed: $sign_output" >&2
        exit 1
    }
    sig=$(printf '%s' "$sign_output" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2 || true)
    if [ -z "$sig" ]; then
        echo "Error: no Sparkle edSignature in sign_update output: $sign_output" >&2
        exit 1
    fi
    # Update appcast + the docs site download link
    python3 scripts/update-appcast.py "{{version}}" "{{build_number}}" "$zip_path" docs/appcast.xml "$sig"
    just update-download
    # Create GitHub release
    if gh release view "v{{version}}" &>/dev/null; then
        echo "Release v{{version}} already exists"
    else
        if [ -f "$notes_path" ]; then
            gh release create "v{{version}}" --draft --title "v{{version}}" --notes-file "$notes_path"
        else
            echo "Warning: no release notes found at $notes_path; creating draft release with fallback notes."
            gh release create "v{{version}}" --draft --title "v{{version}}" --notes "Release {{version}}"
        fi
    fi
    gh release upload "v{{version}}" "$zip_path" --clobber
    echo "Draft release v{{version}} created. Review and publish on GitHub."

# Update the download link + "Latest release" badge in docs/index.html to point at the current version. Called from `just release`.
update-download:
    #!/usr/bin/env bash
    set -euo pipefail
    sed -i '' -E \
      -e "s|releases/tag/v[0-9]+\.[0-9]+\.[0-9]+|releases/tag/v{{version}}|g" \
      -e "s|releases/download/v[0-9]+\.[0-9]+\.[0-9]+/GhostTile-[0-9]+\.[0-9]+\.[0-9]+\.zip|releases/download/v{{version}}/GhostTile-{{version}}.zip|g" \
      -e "s|>v[0-9]+\.[0-9]+\.[0-9]+ on GitHub<|>v{{version}} on GitHub<|g" \
      docs/index.html
    echo "Updated docs/index.html download links to v{{version}}"

# Update the Homebrew tap cask at ../tap/Casks/ghosttile.rb with the new version + sha256. Run after `just release`.
update-cask:
    #!/usr/bin/env bash
    set -euo pipefail
    zip_path="dist/GhostTile-{{version}}.zip"
    if [ ! -f "$zip_path" ]; then
        echo "Expected archive at $zip_path. Run 'just release' first." >&2
        exit 1
    fi
    sha256=$(shasum -a 256 "$zip_path" | cut -d' ' -f1)
    cask_path="../tap/Casks/ghosttile.rb"
    sed -i '' \
      -e 's/version "[^"]*"/version "{{version}},{{build_number}}"/' \
      -e "s/sha256 \"[^\"]*\"/sha256 \"$sha256\"/" \
      "$cask_path"
    echo "Updated $cask_path with version {{version}} sha256 $sha256"

# Build ad-hoc signed zip + sha256 sidecar — no notarization or network, sanity check before `release`.
release-dry-run: build
    #!/usr/bin/env bash
    set -euo pipefail
    codesign --verify --deep --strict --verbose=2 "{{app}}"
    zip_path="dist/GhostTile-{{version}}-dryrun.zip"
    rm -f "$zip_path.sha256"
    bash scripts/package-release-zip.sh "{{app}}" "$zip_path"
    bash scripts/verify-release-archive.sh "$zip_path" signed
    shasum -a 256 "$zip_path" | tee "$zip_path.sha256"
    echo "Dry-run artifact: $zip_path"

# Run SwiftLint over Sources/ and Tests/.
lint:
    swiftlint lint --quiet Sources/ Tests/

# Apply SwiftFormat edits to Sources/ and Tests/.
format:
    swiftformat Sources/ Tests/

# Check SwiftFormat compliance without modifying files (CI-style).
format-check:
    swiftformat --lint Sources/ Tests/

# Remove .build, the local GhostTile.app, and dist/ artifacts.
clean:
    rm -rf .build "{{app}}" dist
