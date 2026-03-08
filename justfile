default:
    @just --list

app := "GhostTile.app"

build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building {{app}}..."
    swift build -c release --product GhostTileApp
    swift build -c release --product ghosttile
    echo "Compiling ghosthide.dylib..."
    xcrun clang -dynamiclib -arch arm64 -arch x86_64 -framework Cocoa \
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
    swift build -c release --product ghosttile

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
