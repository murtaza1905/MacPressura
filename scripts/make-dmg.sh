#!/bin/bash
# Packages MacPressura.app into a distributable disk image.
#
# Usage:
#   ./scripts/make-dmg.sh              build first (scripts/build.sh), then package
#   ./scripts/make-dmg.sh --app PATH   package an already built MacPressura.app
#
# Output: dist/MacPressura-<version>.dmg
# Uses create-dmg (https://github.com/create-dmg/create-dmg) for the window layout
# when it is installed, and falls back to a plain hdiutil image otherwise.
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="MacPressura"
APP=""

while [ $# -gt 0 ]; do
    case "$1" in
        --app) APP="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$APP" ]; then
    ./scripts/build.sh
    APP="build/$APP_NAME.app"
fi
[ -d "$APP" ] || { echo "App bundle not found: $APP" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DIST="dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGING="build/dmg-staging"
ICON="$APP/Contents/Resources/AppIcon.icns"

echo "==> Creating $DMG"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING" "$DIST"
cp -R "$APP" "$STAGING/$APP_NAME.app"

if command -v create-dmg >/dev/null 2>&1; then
    args=(
        --volname "$APP_NAME $VERSION"
        --window-pos 200 120
        --window-size 660 400
        --icon-size 128
        --text-size 14
        --icon "$APP_NAME.app" 180 170
        --hide-extension "$APP_NAME.app"
        --app-drop-link 480 170
        --no-internet-enable
    )
    [ -f "$ICON" ] && args+=(--volicon "$ICON")
    if ! create-dmg "${args[@]}" "$DMG" "$STAGING"; then
        echo "create-dmg failed; falling back to hdiutil." >&2
        rm -f "$DMG"
    fi
fi

if [ ! -f "$DMG" ]; then
    ln -sfn /Applications "$STAGING/Applications"
    hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
fi

rm -rf "$STAGING"
echo
echo "Disk image: $DMG"
