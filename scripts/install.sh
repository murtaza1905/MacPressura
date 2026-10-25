#!/bin/bash
# Builds MacPressura (scripts/build.sh), replaces the copy in /Applications,
# registers it with Launch Services and launches it. Run again to update.
#
# Usage:
#   ./scripts/install.sh            build, install and launch
#   ./scripts/install.sh --no-run   build and install only
#   ./scripts/install.sh --clean    clean build first (passed to scripts/build.sh)
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="MacPressura"
INSTALL_DIR="/Applications"
RUN_AFTER_BUILD=1
BUILD_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --no-run) RUN_AFTER_BUILD=0 ;;
    --clean) BUILD_ARGS+=(--clean) ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

./scripts/build.sh ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}
BUILT_APP="build/$APP_NAME.app"

printf '\n\033[1;34m==> Installing to %s/%s.app\033[0m\n' "$INSTALL_DIR" "$APP_NAME"
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi
if [ -w "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
  ditto "$BUILT_APP" "$INSTALL_DIR/$APP_NAME.app"
else
  echo "Administrator password is needed to write to $INSTALL_DIR"
  sudo rm -rf "$INSTALL_DIR/$APP_NAME.app"
  sudo ditto "$BUILT_APP" "$INSTALL_DIR/$APP_NAME.app"
fi
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

# Register the app and its document types with Launch Services.
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREG" ] && "$LSREG" -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true

printf '\n\033[1;34m==> Done: %s/%s.app\033[0m\n' "$INSTALL_DIR" "$APP_NAME"
if [ "$RUN_AFTER_BUILD" = "1" ]; then
  open -a "$INSTALL_DIR/$APP_NAME.app"
fi
