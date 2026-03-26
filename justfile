default:
    @just --list

app := "GhostTile.app"
deployment_target := "15.0"

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
    mkdir -p Sources/GhostTileApp/app.icon/Assets
    cp docs/imgs/icon.svg Sources/GhostTileApp/app.icon/Assets/ghost.svg
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
build_number := "17"

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

release: notarize-release
    #!/usr/bin/env bash
    set -euo pipefail
    zip_path="dist/GhostTile-{{version}}.zip"
    # Sign for Sparkle
    sparkle_bin=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | head -1)
    sig=""
    if [ -n "$sparkle_bin" ]; then
        sig=$("$sparkle_bin" "$zip_path" 2>/dev/null | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2 || true)
    fi
    # Update appcast
    python3 scripts/update-appcast.py "{{version}}" "{{build_number}}" "$zip_path" docs/appcast.xml "$sig"
    # Create GitHub release
    if gh release view "v{{version}}" &>/dev/null; then
        echo "Release v{{version}} already exists"
    else
        gh release create "v{{version}}" --draft --title "v{{version}}" --notes "Release {{version}}"
    fi
    gh release upload "v{{version}}" "$zip_path" --clobber
    echo "Draft release v{{version}} created. Review and publish on GitHub."

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
      -e 's/version "[^"]*"/version "{{version}}"/' \
      -e "s/sha256 \"[^\"]*\"/sha256 \"$sha256\"/" \
      "$cask_path"
    echo "Updated $cask_path with version {{version}} sha256 $sha256"

lint:
    swiftlint lint --quiet Sources/ Tests/

format:
    swiftformat Sources/ Tests/

format-check:
    swiftformat --lint Sources/ Tests/

clean:
    rm -rf .build "{{app}}" dist
