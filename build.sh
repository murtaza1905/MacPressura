#!/bin/bash
# MacPressura one-shot build:
#   fetches 7zz -> generates the Xcode project -> builds a universal Release app
#   -> installs it to /Applications -> launches it.
#
# Usage:
#   ./build.sh            build, install to /Applications and launch
#   ./build.sh --no-run   build and install only
#   ./build.sh --clean    remove build products and caches, then build
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
APP_NAME="MacPressura"
SCHEME="MacPressura"
INSTALL_DIR="/Applications"
TOOLS_DIR="$ROOT/.tools"
DERIVED="$ROOT/build/DerivedData"
RUN_AFTER_BUILD=1

for arg in "$@"; do
  case "$arg" in
    --no-run) RUN_AFTER_BUILD=0 ;;
    --clean)
      rm -rf "$ROOT/build" "$ROOT/$APP_NAME.xcodeproj" "$ROOT/Vendor/7zz"
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- Xcode check
log "Checking Xcode"
if ! xcode-select -p >/dev/null 2>&1 || [ ! -x "$(xcode-select -p)/usr/bin/xcodebuild" ]; then
  cat >&2 <<'EOF'
Xcode is required (the Command Line Tools alone cannot build a SwiftUI app).
  1. Install Xcode from the App Store.
  2. Open Xcode once and accept the license.
  3. Run:  sudo xcode-select -s /Applications/Xcode.app
  4. Run ./build.sh again.
EOF
  exit 1
fi
XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -1 || true)"
echo "$XCODE_VERSION"

# ---------------------------------------------------------------- XcodeGen
log "Checking XcodeGen"
XCODEGEN=""
if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN="$(command -v xcodegen)"
elif [ -x "$TOOLS_DIR/xcodegen/bin/xcodegen" ]; then
  XCODEGEN="$TOOLS_DIR/xcodegen/bin/xcodegen"
else
  echo "XcodeGen not found; downloading a local copy into .tools (no Homebrew needed)..."
  mkdir -p "$TOOLS_DIR"
  TMP_ZIP="$(mktemp -t xcodegen).zip"
  curl -fsSL --retry 3 -o "$TMP_ZIP" \
    "https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip"
  rm -rf "$TOOLS_DIR/xcodegen"
  unzip -q -o "$TMP_ZIP" -d "$TOOLS_DIR"
  rm -f "$TMP_ZIP"
  xattr -dr com.apple.quarantine "$TOOLS_DIR/xcodegen" 2>/dev/null || true
  XCODEGEN="$TOOLS_DIR/xcodegen/bin/xcodegen"
  [ -x "$XCODEGEN" ] || fail "XcodeGen download failed."
fi
"$XCODEGEN" --version

# ---------------------------------------------------------------- 7zz
log "Preparing 7-Zip engine (7zz)"
chmod +x "$ROOT/scripts/fetch-7zz.sh"
"$ROOT/scripts/fetch-7zz.sh"
[ -x "$ROOT/Vendor/7zz/7zz" ] || fail "Vendor/7zz/7zz is missing."
# Make sure the engine carries a signature even when it came from an older cache.
if ! codesign --verify "$ROOT/Vendor/7zz/7zz" >/dev/null 2>&1; then
  codesign --force --sign - "$ROOT/Vendor/7zz/7zz"
fi

# ---------------------------------------------------------------- Generate
log "Generating Xcode project"
"$XCODEGEN" generate --spec "$ROOT/project.yml" --project "$ROOT" --quiet

# ---------------------------------------------------------------- Build
log "Building $APP_NAME (Release, universal)"
xcodebuild \
  -project "$ROOT/$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  -quiet \
  build

BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
[ -d "$BUILT_APP" ] || fail "Build product not found at $BUILT_APP"

# Make sure the bundled engine is executable and the whole bundle is ad-hoc signed.
chmod +x "$BUILT_APP/Contents/MacOS/7zz" 2>/dev/null || true
codesign --force --deep --sign - "$BUILT_APP" >/dev/null 2>&1 || true

# ---------------------------------------------------------------- Install
log "Installing to $INSTALL_DIR/$APP_NAME.app"
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

# Register the app and its document types with Launch Services.
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREG" ] && "$LSREG" -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true

log "Done: $INSTALL_DIR/$APP_NAME.app"
if [ "$RUN_AFTER_BUILD" = "1" ]; then
  open -a "$INSTALL_DIR/$APP_NAME.app"
fi
