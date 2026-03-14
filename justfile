default:
    @just --list

app := "GhostTile.app"
deployment_target := "15.0"

build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building {{app}}..."
    MACOSX_DEPLOYMENT_TARGET={{deployment_target}} swift build -c release --product GhostTileApp
    MACOSX_DEPLOYMENT_TARGET={{deployment_target}} swift build -c release --product ghosttile
    echo "Compiling ghosthide.dylib..."
    xcrun clang -dynamiclib -arch arm64 -arch x86_64 -framework Cocoa \
        -mmacosx-version-min={{deployment_target}} \
        -o .build/ghosthide.dylib Resources/ghosthide.m
    rm -rf "{{app}}"
    mkdir -p "{{app}}/Contents/MacOS" "{{app}}/Contents/Resources"
    cp .build/release/GhostTileApp "{{app}}/Contents/MacOS/GhostTile"
    cp Resources/Info.plist "{{app}}/Contents/"
    cp Resources/appIcon.icns "{{app}}/Contents/Resources/"
    cp Resources/status_menu_v.pdf "{{app}}/Contents/Resources/"
    cp Resources/ghost-icon.png "{{app}}/Contents/Resources/"
    cp Resources/appIcon-old.png "{{app}}/Contents/Resources/"
    cp Resources/appIcon-new.png "{{app}}/Contents/Resources/"
    cp .build/ghosthide.dylib "{{app}}/Contents/Resources/"
    codesign --force --sign - "{{app}}"
    cp .build/release/ghosttile "{{app}}/Contents/Resources/ghosttile-cli"
    echo "Built {{app}} ($(du -sh "{{app}}" | cut -f1))"

build-cli:
    MACOSX_DEPLOYMENT_TARGET={{deployment_target}} swift build -c release --product ghosttile

resign app:
    #!/usr/bin/env bash
    set -euo pipefail
    MACOSX_DEPLOYMENT_TARGET={{deployment_target}} swift build -c release --product ghosttile
    .build/release/ghosttile manage --force-prepare "{{app}}"

resign-all:
    #!/usr/bin/env bash
    set -euo pipefail
    MACOSX_DEPLOYMENT_TARGET={{deployment_target}} swift build -c release --product ghosttile
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
        .build/release/ghosttile manage --force-prepare "$app_path"
    done <<< "$app_paths"

run: kill build
    open "{{app}}"

kill:
    -pkill -f "{{app}}/Contents/MacOS/GhostTile"

restart: kill run

icon:
    swift scripts/generate-icon.swift Resources

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

clean:
    rm -rf .build "{{app}}" dist
