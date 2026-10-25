#!/bin/bash
# Quits MacPressura, removes the app from /Applications and deletes its settings.
set -uo pipefail

APP_NAME="MacPressura"
BUNDLE_ID="com.muratonurcu.MacPressura"

echo "==> Quitting $APP_NAME"
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
sleep 1

echo "==> Removing application"
if [ -d "/Applications/$APP_NAME.app" ] && [ ! -w /Applications ]; then
    sudo rm -rf "/Applications/$APP_NAME.app"
else
    rm -rf "/Applications/$APP_NAME.app"
fi
rm -rf ~/Applications/"$APP_NAME".app

echo "==> Removing settings"
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
rm -rf ~/Library/Caches/"$BUNDLE_ID"
rm -rf ~/Library/Saved\ Application\ State/"$BUNDLE_ID".savedState
rm -rf ~/Library/HTTPStorages/"$BUNDLE_ID"

echo "==> Removing build output"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$SCRIPT_DIR/build" "$SCRIPT_DIR/dist" "$SCRIPT_DIR/$APP_NAME.xcodeproj"

echo
echo "$APP_NAME has been removed. To reinstall from scratch: ./scripts/install.sh"
