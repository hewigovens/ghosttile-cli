default:
    @just --list

app := "GhostTile.app"
deployment_target := "15.0"

build: build-cli
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building {{app}} via Xcode..."
    xcodegen generate --spec project.yml --project .
    xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Release build 2>&1 | xcbeautify
    app_path="$(xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/GhostTile.app"
    rm -rf "{{app}}"
    cp -R "$app_path" "{{app}}"
    codesign --force --sign - "{{app}}"
    echo "Built {{app}} ($(du -sh "{{app}}" | cut -f1))"

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
        -o .build/ghosthide.dylib Resources/ghosthide.m Resources/fishhook.c
    cp .build/ghosthide.dylib .build/release/ghosthide.dylib

resign app:
    #!/usr/bin/env bash
    set -euo pipefail
    just build-cli
    sudo .build/release/ghosttile prepare --force "{{app}}"

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

run: kill build-cli
    #!/usr/bin/env bash
    set -euo pipefail
    xcodegen generate --spec project.yml --project .
    xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Debug build 2>&1 | xcbeautify
    app_path="$(xcodebuild -project GhostTile.xcodeproj -scheme GhostTileApp -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/GhostTile.app"
    open "$app_path"

kill:
    -pkill -f "{{app}}/Contents/MacOS/GhostTile"

restart: kill run

install: build
    cp -r "{{app}}" /Applications/
    @echo "Installed to /Applications/{{app}}"

version := "2.0.0"

dist: build
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p dist
    cd dist && rm -f GhostTile-{{version}}.zip
    ditto -c -k --keepParent "../{{app}}" "GhostTile-{{version}}.zip"
    echo "Created dist/GhostTile-{{version}}.zip ($(du -sh "GhostTile-{{version}}.zip" | cut -f1))"
    shasum -a 256 "GhostTile-{{version}}.zip"

sign-release: build
    #!/usr/bin/env bash
    set -euo pipefail
    signing_identity="${DEVELOPER_ID_APPLICATION:-Developer ID Application: Tao Xu (V28VJH6B6S)}"
    echo "Signing {{app}} with ${signing_identity}..."
    codesign --force --timestamp --sign "${signing_identity}" "{{app}}/Contents/Resources/ghosthide.dylib"
    codesign --force --timestamp --options runtime --sign "${signing_identity}" "{{app}}/Contents/Resources/ghosttile-cli"
    codesign --force --timestamp --options runtime --sign "${signing_identity}" "{{app}}"
    codesign --verify --deep --strict --verbose=2 "{{app}}"
    echo "Signed {{app}}"

notarize-release: sign-release
    #!/usr/bin/env bash
    set -euo pipefail
    notary_profile="${NOTARY_PROFILE:-notarytool}"
    mkdir -p dist
    rm -f "dist/GhostTile-{{version}}.zip"
    ditto -c -k --keepParent "{{app}}" "dist/GhostTile-{{version}}.zip"
    echo "Submitting dist/GhostTile-{{version}}.zip for notarization with profile ${notary_profile}..."
    xcrun notarytool submit "dist/GhostTile-{{version}}.zip" --keychain-profile "${notary_profile}" --wait
    xcrun stapler staple "{{app}}"
    xcrun stapler validate "{{app}}"
    rm -f "dist/GhostTile-{{version}}.zip"
    ditto -c -k --keepParent "{{app}}" "dist/GhostTile-{{version}}.zip"
    echo "Created notarized dist/GhostTile-{{version}}.zip ($(du -sh "dist/GhostTile-{{version}}.zip" | cut -f1))"
    shasum -a 256 "dist/GhostTile-{{version}}.zip"

clean:
    rm -rf .build "{{app}}" dist
